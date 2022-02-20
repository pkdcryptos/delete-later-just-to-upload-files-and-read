class Member < ActiveRecord::Base
  acts_as_taggable
  acts_as_reader

  has_many :accounts
  has_many :payment_addresses, through: :accounts
  has_many :withdraws
  has_many :deposits
  has_many :api_tokens
  has_one :bpitoken
	has_one :ethdoc
  has_one :btcdoc
  has_one :ltcdoc
  has_one :trxdoc
  has_one :usdtdoc

  scope :enabled, -> { where(disabled: false) }

  
  before_validation :sanitize, :generate_sn

  validates :sn, presence: true
  validates :email, email: true, uniqueness: true, allow_nil: true

  after_create  :touch_accounts
  
  after_update :sync_update

  class << self
    
    def current
      Thread.current[:user]
    end

    def current=(user)
      Thread.current[:user] = user
    end

    def admins
      Figaro.env.admin.split(',')
    end

    

    private

    
  end


  

  def active!
    update activated: true
  end

  
  def admin?
    @is_admin ||= self.class.admins.include?(self.email)
  end

  

  def trigger(event, data)
    AMQPQueue.enqueue(:pusher_member, {member_id: id, event: event, data: data})
  end

  def notify(event, data)
    ::Pusher["private-#{sn}"].trigger_async event, data
  end

  def to_s
    "#{email} - #{sn}"
  end

  def gravatar
    "//gravatar.com/avatar/" + Digest::MD5.hexdigest(email.strip.downcase) + "?d=retro"
  end

  

  def get_account(currency)
    account = accounts.with_currency(currency.to_sym).first

    if account.nil?
      touch_accounts
      account = accounts.with_currency(currency.to_sym).first
    end

    account
  end
  alias :ac :get_account

  def touch_accounts
    less = Currency.codes - self.accounts.map(&:currency).map(&:to_sym)
    less.each do |code|
      self.accounts.create(currency: code, balance: 0, locked: 0)
    end
  end

  
  def send_activation
    Token::Activation.create(member: self)
  end

  


  private

  def sanitize
    self.email.try(:downcase!)
  end

  def generate_sn
    self.sn and return
    begin
      self.sn = "PEA#{ROTP::Base32.random_base32(8).upcase}TIO"
    end while Member.where(:sn => self.sn).any?
  end

  

  def sync_update
    ::Pusher["private-#{sn}"].trigger_async('members', { type: 'update', id: self.id, attributes: self.changes_attributes_as_json })
  end
end
