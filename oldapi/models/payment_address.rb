class PaymentAddress < ActiveRecord::Base
  include Currencible
  belongs_to :account

  after_commit :gen_address, on: :create

  has_many :transactions, class_name: 'PaymentTransaction', foreign_key: 'address', primary_key: 'address'

  validates_uniqueness_of :address, allow_nil: true

  def gen_address
#     payload = { payment_address_id: id, currency: currency }
#     attrs   = { persistent: true }
#     AMQPQueue.enqueue(:deposit_coin_address, payload, attrs)
#     
    
    payment_address = PaymentAddress.find id
      return if payment_address.address.present?

      
      #make sure the generated address is unqiue for that currency.
      # we took off uniqueness validation clause of payment address table, as same address can be used for all erc tokens.
      # or better put uniqueness validation on combination of address and currency
      if currency == 'eth' || currency == 'erc'  || currency == 'xyz'   || currency == 'abc'   || currency == 'p2p' 
        address = payment_address.account.member.ethdoc.address
        
        address = currency + '_' + address
        ##Rails.logger.info "DBG: address: #{address}"
      end
      if currency == 'btc'
		Rails.logger.info "DBG1: currency btc get the address thru member"
        address  = payment_address.account.member.btcdoc.address
		Rails.logger.info "DBG1:-- address #{address.inspect}"
      end
      if currency == 'ltc'
        address  = payment_address.account.member.ltcdoc.address
      end
	  if currency == 'trx'  || currency == 'usdt'
	    Rails.logger.info "DBG1: currency trx get the address thru member"
        address  = payment_address.account.member.trxdoc.address
		address = currency + '_' + address
      end
	 

      if payment_address.update address: address
        #::Pusher["private-#{payment_address.account.member.sn}"].trigger_async('deposit_address', { type: 'create', attributes: payment_address.as_json})
      end
      
      
  end

  def memo
    address && address.split('|', 2).last
  end

  def deposit_address
    currency_obj[:deposit_account] || address
  end

  def as_json(options = {})
    {
      account_id: account_id,
      deposit_address: deposit_address
    }.merge(options)
  end

  def trigger_deposit_address
    #::Pusher["private-#{account.member.sn}"].trigger_async('deposit_address', {type: 'create', attributes: as_json})
    puts "Not sending for now"
  end

  def self.construct_memo(obj)
    member = obj.is_a?(Account) ? obj.member : obj
    checksum = member.created_at.to_i.to_s[-3..-1]
    "#{member.id}#{checksum}"
  end

  def self.destruct_memo(memo)
    member_id = memo[0...-3]
    checksum  = memo[-3..-1]

    member = Member.find_by_id member_id
    return nil unless member
    return nil unless member.created_at.to_i.to_s[-3..-1] == checksum
    member
  end

  def to_json
    {address: deposit_address}
  end

end
