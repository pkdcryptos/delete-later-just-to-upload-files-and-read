class Withdraw < ActiveRecord::Base
  STATES = [:submitting, :submitted, :rejected, :accepted, :suspect, :processing,
            :done, :canceled, :almost_done, :failed]
  COMPLETED_STATES = [:done, :rejected, :canceled, :almost_done, :failed]

  extend Enumerize

  include AASM
  include AASM::Locking
  include Currencible

  has_paper_trail on: [:update, :destroy]

  enumerize :aasm_state, in: STATES, scope: true

  belongs_to :member
  belongs_to :account
  has_many :account_versions, as: :modifiable

  delegate :balance, to: :account, prefix: true
  delegate :key_text, to: :channel, prefix: true
  delegate :id, to: :channel, prefix: true
  delegate :name, to: :member, prefix: true
  delegate :coin?, :fiat?, to: :currency_obj

  before_validation :fix_precision
  before_validation :calc_fee
  before_validation :set_account
  after_create :generate_sn
  
  scope :recent, -> { order('id DESC')}


  after_update :sync_update
  after_create :sync_create
  after_destroy :sync_destroy

  validates_with WithdrawBlacklistValidator

  validates :fund_uid, :amount, :fee, :account, :currency, :member, presence: true

  validates :fee, numericality: {greater_than_or_equal_to: 0}
  validates :amount, numericality: {greater_than: 0}

  validates :sum, presence: true, numericality: {greater_than: 0}, on: :create
  validates :txid, uniqueness: true, allow_nil: true, on: :update

  validate :ensure_account_balance, on: :create

  scope :completed, -> { where aasm_state: COMPLETED_STATES }
  scope :not_completed, -> { where.not aasm_state: COMPLETED_STATES }

  def self.channel
    WithdrawChannel.find_by_key(name.demodulize.underscore)
  end

  def channel
    self.class.channel
  end

  def channel_name
    channel.key
  end

  alias_attribute :withdraw_id, :sn
  alias_attribute :full_name, :member_name

  def generate_sn
    id_part = sprintf '%04d', id
    date_part = created_at.localtime.strftime('%y%m%d%H%M')
    self.sn = "#{date_part}#{id_part}"
    update_column(:sn, sn)
  end

  aasm :whiny_transitions => false do
    state :submitting,  initial: true
    state :submitted,   after_commit: :send_email
    state :canceled
    state :accepted
    state :suspect
    state :rejected
    state :processing
    state :almost_done
    state :done,        after_commit: [:send_email]
    state :failed

    event :submit do
      transitions from: :submitting, to: :submitted
      after do
        lock_funds
      end
    end

    event :cancel do
      transitions from: [:submitting, :submitted, :accepted], to: :canceled
      after do
        after_cancel
      end
    end
	
	event :cancelone do
      transitions from: [:processing], to: :canceled     
    end

    event :mark_suspect do
      transitions from: :submitted, to: :suspect
    end

    event :accept do
      transitions from: :submitted, to: :accepted
    end

    event :reject do
      transitions from: [:submitted, :accepted, :processing], to: :rejected
      after :unlock_funds
    end

    event :process do
      transitions from: :accepted, to: :processing
      after :unlock_and_sub_funds
    end

    event :call_rpc do
      transitions from: :processing, to: :almost_done
    end

    event :succeed do
      transitions from: [:processing, :almost_done], to: :done

      before [:set_txid, :unlock_and_sub_funds]
    end

    event :fail do
      transitions from: :processing, to: :failed
    end
  end

  def cancelable?
    submitting? or submitted? or accepted?
  end

  def quick?
    sum <= currency_obj.quick_withdraw_max
  end

  def audit!
    with_lock do
      mark_suspect_code = 7 # all 3 issues are there (start with this assumption)
      # 3 tests to do: 1) account issues 2) withdraw for 2nd time in last 24 hrs for same coin  3) high volume withdraw
      had_account_issues = true
      if account.examine
      had_account_issues = false
      end
      had_high_volume_withdraw = true
      if quick?
      had_high_volume_withdraw = false
      end
      had_multiple_withdraws = true
      withdraw_24hrs_count = Withdraw.where(member_id: member.id).where('created_at > ?', 1.days.ago).where(currency: currency_obj.id).pluck(:id).size
      self.withdraw_24hrs_count = withdraw_24hrs_count
      if withdraw_24hrs_count == 1
      had_multiple_withdraws = false
      end
      
      if had_account_issues 
      mark_suspect_code=1 
      end
      if had_high_volume_withdraw 
      mark_suspect_code=2 
      end
      if had_multiple_withdraws 
      mark_suspect_code=3 
      end
      if had_account_issues && had_high_volume_withdraw  
      mark_suspect_code=4 
      end
      if had_high_volume_withdraw && had_multiple_withdraws  
      mark_suspect_code=5 
      end
      if had_account_issues && had_multiple_withdraws  
      mark_suspect_code=6 
      end            
      if had_account_issues && had_high_volume_withdraw && had_multiple_withdraws  
      mark_suspect_code=7 
      end            
      
      if had_account_issues or had_high_volume_withdraw or had_multiple_withdraws
      self.mark_suspect_code = mark_suspect_code
      accept # accept with mark_suspect_code 
	  #process
      else
      accept
      process
	  end
      
     
      
     

      save!
    end
  end

  private

  def after_cancel
    unlock_funds unless aasm.from_state == :submitting
  end

  def lock_funds
    account.lock!
    account.lock_funds sum, reason: Account::WITHDRAW_LOCK, ref: self
  end

  def unlock_funds
    account.lock!
    account.unlock_funds sum, reason: Account::WITHDRAW_UNLOCK, ref: self
  end

  def unlock_and_sub_funds
    account.lock!
    account.unlock_and_sub_funds sum, locked: sum, fee: fee, reason: Account::WITHDRAW, ref: self
  end

  def set_txid
    self.txid = @sn unless coin?
  end
  


  def send_email
    case aasm_state
    when 'submitted'
      WithdrawMailer.submitted(self.id).deliver
    when 'processing'
      WithdrawMailer.processing(self.id).deliver
    when 'done'
      WithdrawMailer.done(self.id).deliver
    else
      WithdrawMailer.withdraw_state(self.id).deliver
    end
  end

  

#   def send_coins!
#     AMQPQueue.enqueue(:withdraw_coin, id: id) if coin?
#   end

  def ensure_account_balance
    if sum.nil? or sum > account.balance
      errors.add :base, -> { I18n.t('activerecord.errors.models.withdraw.account_balance_is_poor') }
    end
  end

  def fix_precision
    if sum && currency_obj.precision
      self.sum = sum.round(currency_obj.precision, BigDecimal::ROUND_DOWN)
    end
  end

  def calc_fee
    if respond_to?(:set_fee)
      set_fee
    end

    self.sum ||= 0.0
    self.fee ||= 0.0
    self.amount = sum - fee
  end

  def set_account
    self.account = member.get_account(currency)
  end

  def self.resource_name
    name.demodulize.underscore.pluralize
  end

  def sync_update
    #::Pusher["private-#{member.sn}"].trigger_async('withdraws', { type: 'update', id: self.id, attributes: self.changes_attributes_as_json })
    puts "Not sending for now"
  end

  def sync_create
    #::Pusher["private-#{member.sn}"].trigger_async('withdraws', { type: 'create', attributes: self.as_json })
    puts "Not sending for now"
  end

  def sync_destroy
    #::Pusher["private-#{member.sn}"].trigger_async('withdraws', { type: 'destroy', id: self.id })
    puts "Not sending for now"
  end


end
