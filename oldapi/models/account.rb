class Account < ActiveRecord::Base
  include Currencible

  FIX = :fix
  UNKNOWN = :unknown
  STRIKE_ADD = :strike_add
  STRIKE_SUB = :strike_sub
  STRIKE_FEE = :strike_fee
  STRIKE_UNLOCK = :strike_unlock
  ORDER_CANCEL = :order_cancel
  ORDER_SUBMIT = :order_submit
  ORDER_FULLFILLED = :order_fullfilled
  WITHDRAW_LOCK = :withdraw_lock
  WITHDRAW_UNLOCK = :withdraw_unlock
  DEPOSIT = :deposit
  WITHDRAW = :withdraw
  
   
  
  OLDCODE_INTERNAL_DEPOSIT = :oldcode_internal_deposit
  OLDCODE_INTERNAL_WITHDRAW = :oldcode_internal_withdraw  
  OLDCODE_PTP_DEPOSIT = :oldcode_ptp_deposit
  OLDCODE_PTP_WITHDRAW = :oldcode_ptp_withdraw 
  

  
  PTP_CREATED_TRADE = :ptp_created_trade  
  PTP_DISPUTE_RESOLVED = :ptp_dispute_resolved  
  PTP_REOPENED_TRADE = :ptp_reopened_trade  
  PTP_CANCELLED_TRADE = :ptp_cancelled_trade  
  PTP_ESCROW_RELEASED = :ptp_escrow_released  
  ADMIN_TRANSFER  = :admin_transfer  

  
 
  
  
  
  ZERO = 0.to_d

  FUNS = {:unlock_funds => 1, :lock_funds => 2, :plus_funds => 3, :sub_funds => 4, :unlock_and_sub_funds => 5}

  belongs_to :member
  has_many :payment_addresses
  has_many :versions, class_name: "::AccountVersion"
  has_many :partial_trees

  # Suppose to use has_one here, but I want to store
  # relationship at account side. (Daniel)
  belongs_to :default_withdraw_fund_source, class_name: 'FundSource'

  validates :member_id, uniqueness: { scope: :currency }
  validates_numericality_of :balance, :locked, greater_than_or_equal_to: ZERO

  scope :enabled, -> { where("currency in (?)", Currency.ids) }

  after_commit :trigger, :sync_update

  def payment_address
    payment_addresses.last || payment_addresses.create(currency: self.currency)
  end

  def self.after(*names)
    names.each do |name|
      m = instance_method(name.to_s)
      define_method(name.to_s) do |*args, &block|
        m.bind(self).(*args, &block)
        yield(self, name.to_sym, *args)
        self
      end
    end
  end

   def plus_funds(amount, fee: ZERO, reason: nil, ref: nil, reason1: nil, reason2: nil, reason3: nil)
    #(amount <= ZERO or fee > amount) and raise AccountError, "cannot add funds (amount: #{amount}, fee: #{fee}, record: #{self.inspect})"
    (amount <= ZERO or fee > amount) and raise AccountError, "cannot add funds (amount: #{amount})"
    change_balance_and_locked amount, 0
  end

  def sub_funds(amount, fee: ZERO, reason: nil, ref: nil, reason1: nil, reason2: nil, reason3: nil)
    
    #(amount <= ZERO or amount > self.balance) and raise AccountError, "cannot subtract funds (amount: #{amount}, balance: #{self.balance}, record: #{self.inspect})"
    (amount <= ZERO or amount > self.balance) and raise AccountError, "cannot subtract funds (amount: #{amount})"
    change_balance_and_locked -amount, 0
  end

  def lock_funds(amount, reason: nil, ref: nil)
    #(amount <= ZERO or amount > self.balance) and raise AccountError, "cannot lock funds (amount: #{amount}, balance: #{self.balance}, record: #{self.inspect})"
    (amount <= ZERO or amount > self.balance) and raise AccountError, "cannot lock funds (amount: #{amount})"
    change_balance_and_locked -amount, amount
  end

  def unlock_funds(amount, reason: nil, ref: nil)
    #(amount <= -0.00000001 or amount > self.locked) and raise AccountError, "cannot unlock funds (amount: #{amount}, locked: #{self.locked}, record: #{self.inspect})"
    (amount <= -0.00000001 or amount > self.locked) and raise AccountError, "cannot unlock funds (amount: #{amount})"
    if (amount <= ZERO) 
    else
    change_balance_and_locked amount, -amount
    end
  end

  def unlock_and_sub_funds(amount, locked: ZERO, fee: ZERO, reason: nil, ref: nil)
#     raise AccountError, "cannot unlock and subtract funds (amount: #{amount}, locked: #{locked}, self.locked: #{self.locked}, record: #{self.inspect})" if ((amount <= 0) || (amount > locked))
#     raise LockedError, "invalid lock amount (amount: #{amount}, locked: #{locked}, self.locked: #{self.locked}, record: #{self.inspect})" unless locked
#     raise LockedError, "invalid lock amount (amount: #{amount}, locked: #{locked}, self.locked: #{self.locked}, record: #{self.inspect})" if ((locked <= 0) || (locked > self.locked))
    raise AccountError, "cannot unlock and subtract funds (amount: #{amount})" if ((amount <= 0) || (amount > locked))
    raise LockedError, "invalid lock amount" unless locked
    raise LockedError, "invalid lock amount (amount: #{amount}, locked: #{locked}, self.locked: #{self.locked})" if ((locked <= 0) || (locked > self.locked))
    change_balance_and_locked locked-amount, -locked
  end

  after(*FUNS.keys) do |account, fun, changed, opts|
    begin
      opts ||= {}
      fee = opts[:fee] || ZERO
      reason = opts[:reason] || Account::UNKNOWN
	  reason1 = opts[:reason1]
	  reason2 = opts[:reason2] || ''
	  reason3 = opts[:reason3] || ''

      attributes = { fun: fun,
                     fee: fee,
                     reason: reason,
                     reason1: reason1,
                     reason2: reason2,
                     reason3: reason3,
                     amount: account.amount,
                     currency: account.currency.to_sym,
                     member_id: account.member_id,
                     account_id: account.id }

      if opts[:ref] and opts[:ref].respond_to?(:id)
        ref_klass = opts[:ref].class
        attributes.merge! \
          modifiable_id: opts[:ref].id,
          modifiable_type: ref_klass.respond_to?(:base_class) ? ref_klass.base_class.name : ref_klass.name
      end

      locked, balance = compute_locked_and_balance(fun, changed, opts)
      attributes.merge! locked: locked, balance: balance

      AccountVersion.optimistically_lock_account_and_create!(account.balance, account.locked, attributes)
    rescue ActiveRecord::StaleObjectError
      #Rails.logger.info "DBG: Stale account##{account.id} found when create associated account version, retry."
      account = Account.find(account.id)
      raise ActiveRecord::RecordInvalid, account unless account.valid?
      retry
    end
  end

  def self.compute_locked_and_balance(fun, amount, opts)
    raise AccountError, "invalid account operation" unless FUNS.keys.include?(fun)

    case fun
    when :sub_funds then [ZERO, ZERO - amount]
    when :plus_funds then [ZERO, amount]
    when :lock_funds then [amount, ZERO - amount]
    when :unlock_funds then [ZERO - amount, amount]
    when :unlock_and_sub_funds
      locked = ZERO - opts[:locked]
      balance = opts[:locked] - amount
      [locked, balance]
    else raise AccountError, "forbidden account operation"
    end
  end

  def amount
    self.balance + self.locked
  end

  def last_version
    versions.last
  end

  def examine
    expected = 0
    versions.find_each(batch_size: 100000) do |v|
      expected += v.amount_change
      return false if expected != v.amount
    end

    expected == self.amount
  end
  
  def examine_display
    expected = 0
    versions.find_each(batch_size: 100000) do |v|
      expected += v.amount_change
      return {expected: expected, amount: v.amount, status: 'midway', id: v.id} if expected != v.amount
    end

    {expected: expected, amount: self.amount, status: 'complete'}
  end

  def trigger
    return unless member

    json = Jbuilder.encode do |json|
      json.(self, :balance, :locked, :currency)
    end
    #member.trigger('account', json)
    if self.member_id==2 or 1==1
    member.trigger('pvtAccountUpdate', json)  #executionReport is renamed as pvtAccountUpdate
    end
  end

  def change_balance_and_locked(delta_b, delta_l)
    self.balance += delta_b
    self.locked  += delta_l
    self.class.connection.execute "update accounts set balance = balance + #{delta_b}, locked = locked + #{delta_l} where id = #{id}"
    add_to_transaction # so after_commit will be triggered
    self
  end

  scope :locked_sum, -> (currency) { with_currency(currency).sum(:locked) }
  scope :balance_sum, -> (currency) { with_currency(currency).sum(:balance) }

  class AccountError < RuntimeError; end
  class LockedError < AccountError; end
  class BalanceError < AccountError; end

  def as_json(options = {})
    super(options).merge({
      # check if there is a useable address, but don't touch it to create the address now.
      "deposit_address" => payment_addresses.empty? ? "" : payment_address.deposit_address,
      "name_text" => currency_obj.name_text,
      "default_withdraw_fund_source_id" => default_withdraw_fund_source_id
    })
  end

  private

  def sync_update
     #Rails.logger.info "DBG: Account record: id: #{self.id}, member_id: #{member_id}, currency: #{currency}, balance: #{balance}, locked: #{locked}"
	 #if self.member_id==1 || self.member_id>900
	::Pusher["private-#{member.sn}"].trigger_async('accounts', { type: 'update', id: self.id, attributes: {balance: balance, locked: locked} })
	#end
  end

end
