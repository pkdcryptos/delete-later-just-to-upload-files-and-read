require_relative 'matching/constants'
class Order < ActiveRecord::Base
  extend Enumerize

  enumerize :bid, in: Currency.enumerize
  enumerize :ask, in: Currency.enumerize
  enumerize :currency, in: Market.enumerize, scope: true
  enumerize :state, in: {:wait => 100, :done => 200, :cancel => 0}, scope: true

  ORD_TYPES = %w(market limit)
  enumerize :ord_type, in: ORD_TYPES, scope: true

  SOURCES = %w(Web APIv1 debug)
  enumerize :source, in: SOURCES, scope: true

  after_commit :trigger
  before_validation :fix_number_precision, on: :create

  validates_presence_of :ord_type, :volume, :origin_volume, :locked, :origin_locked
  validates_numericality_of :origin_volume, :greater_than => 0

  validates_numericality_of :price, greater_than: 0, allow_nil: false,
    if: "ord_type == 'limit'"
  validate :market_order_validations, if: "ord_type == 'market'"

  WAIT = 'wait'
  DONE = 'done'
  CANCEL = 'cancel'

  ATTRIBUTES = %w(id member_id at market kind ord_type type price state state_text volume origin_volume last_price last_qty locked origin_locked funds_received isStopLimit isReadyForMatching stopPrice stopPriceTrigger lastTradeIdForThisOrder trades_count)

  belongs_to :member
  attr_accessor :total

  scope :done, -> { with_state(:done) }
  scope :active, -> { with_state(:wait) }
  scope :position, -> { group("price").pluck(:price, 'sum(volume)') }
  scope :best_price, ->(currency) { where(ord_type: 'limit').active.with_currency(currency).matching_rule.position }

  def funds_used
    origin_locked - locked
  end

  def fee
    config[kind.to_sym]["fee"]
  end

  def config
    @config ||= Market.find(currency)
  end

  def trigger
    return unless member
    
    #Rails.logger.info "DBG: Order record: id: #{self.id}, currency: #{currency}, volume: #{volume}, origin_volume: #{origin_volume}, state: #{state}, type: #{type}, member_id: #{member_id}, ord_type: #{ord_type}, locked: #{locked}, origin_locked: #{origin_locked}, funds_received: #{funds_received}"

    json = Jbuilder.encode do |json|
      json.(self, *ATTRIBUTES)
    end
    if self.member_id==2 or 1==1
    member.trigger('pvtOrderUpdate', json)    #executionReport is renamed as pvtOrderUpdate
    end
  end

  def strike(trade)
    raise "Cannot strike on cancelled or done order. id: #{id}, state: #{state}" unless state == Order::WAIT

    real_sub, add = get_account_changes trade
	real_fee      = add * fee
	
	if hold_account.user_type==1 and expect_account.user_type==1
		if trade.ask_member_user_type==1 and trade.bid_member_user_type==1
		real_fee      = 0
		else
		real_fee      = -1 * add * fee
		end	
	end
	
	
    
    real_add      = add - real_fee
    
    Rails.logger.info "DBG: info in strike: hold_account.user_type: #{hold_account.user_type}, expect_account.user_type: #{expect_account.user_type}, hold_account.currency: #{hold_account.currency}, expect_account.currency: #{expect_account.currency}, hold_account.id: #{hold_account.id}, expect_account.id: #{expect_account.id},real_sub: #{real_sub}, add: #{add}, fee: #{fee}, real_fee: #{real_fee}, real_add: #{real_add}, trade record: #{trade.inspect}"

    hold_account.unlock_and_sub_funds \
      real_sub, locked: real_sub,
      reason: Account::STRIKE_SUB, ref: trade

    expect_account.plus_funds \
      real_add, fee: real_fee,
      reason: Account::STRIKE_ADD, ref: trade

    self.volume         -= trade.volume
    self.locked         -= real_sub
    self.funds_received += add
    self.trades_count   += 1
    self.lastTradeIdForThisOrder  = trade.id
    self.last_price = trade.last_price
    self.last_qty = trade.volume

       
    if volume.zero? or volume <= 0.00000002
      self.state = Order::DONE

      # unlock not used funds
      hold_account.unlock_funds locked,
        reason: Account::ORDER_FULLFILLED, ref: trade unless locked.zero?
    elsif ord_type == 'market' && (locked.zero? or locked <= 0.00000002)
      # partially filled market order has run out its locked fund
      self.state = Order::CANCEL
    end


    self.save!
  end

  def kind
    type.underscore[-3, 3]
  end

  def self.head(currency)
    active.with_currency(currency.downcase).matching_rule.first
  end

  def at
    created_at.to_i
  end

  def market
    currency
  end

  def to_matching_attributes
    { id: id,
      market: market,
      memberId: member_id,
      user_type: user_type,
      type: type[-3, 3].downcase.to_sym,
      ord_type: ord_type,
      volume: volume,
      price: price,
      locked: locked,
      timestamp: created_at.to_i,
      isReadyForMatching:  isReadyForMatching,
      isStopLimit:         isStopLimit
      }
  end
  
  def to_matching_attributes_market
    { id: id,
      market: market,
      memberId: member_id,
      user_type: user_type,
	  type: type[-3, 3].downcase.to_sym,
      ord_type: ord_type,
      volume: volume,
      locked: locked,
      timestamp: created_at.to_i,
      isReadyForMatching:  isReadyForMatching,
      isStopLimit:         isStopLimit
      }
  end

  def fix_number_precision
    self.price = config.fix_number_precision(:bid, price.to_d) if price

    if volume
      self.volume = config.fix_number_precision(:ask, volume.to_d)
      self.origin_volume = origin_volume.present? ? config.fix_number_precision(:ask, origin_volume.to_d) : volume
    end
  end

  private

  def market_order_validations
    errors.add(:price, 'must not be present') if price.present?
  end

  FUSE = '0.9'.to_d
  def estimate_required_funds(price_levels)
    required_funds = Account::ZERO
    expected_volume = volume

    start_from, _ = price_levels.first
    filled_at     = start_from

    until expected_volume.zero? || price_levels.empty?
      level_price, level_volume = price_levels.shift
      filled_at = level_price

      v = [expected_volume, level_volume].min
      required_funds += yield level_price, v
      expected_volume -= v
    end

    raise Matching::MarketIsNotDeepEnoughError unless expected_volume.zero?
    raise Matching::VolumeTooLargeError if (filled_at-start_from).abs/start_from > FUSE

    #Rails.logger.info "DBG: volume: #{volume} required_funds: #{required_funds}"
    required_funds
  end

end
