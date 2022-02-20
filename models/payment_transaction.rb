class PaymentTransaction < ActiveRecord::Base
  extend Enumerize

  include AASM
  include AASM::Locking
  include Currencible

  STATE = [:unconfirm, :confirming, :confirmed]
  enumerize :aasm_state, in: STATE, scope: true

  validates_presence_of :txid

  has_one :deposit
  belongs_to :payment_address, foreign_key: 'address', primary_key: 'address'
  has_one :account, through: :payment_address
  has_one :member, through: :account

  after_update :sync_update

  aasm :whiny_transitions => false do
    state :unconfirm, initial: true
    state :confirming, after_commit: :deposit_accept
    state :confirmed, after_commit: :deposit_confirm

    event :check do |e|
      before :refresh_confirmations
			transitions :from => [:unconfirm, :confirming], :to => :confirming, :guard => :min_confirm?
      transitions :from => [:unconfirm, :confirming, :confirmed], :to => :confirmed, :guard => :max_confirm?
    end
  end
	
	


  def min_confirm?
		Rails.logger.info "DBG:TRACK_CONFIRMS: min_conform check  #{deposit.txid} "
    deposit.min_confirm?(confirmations)
  end

  def max_confirm?
	Rails.logger.info "DBG:TRACK_CONFIRMS: max_conform check  #{deposit.txid}"
    deposit.max_confirm?(confirmations)
  end
  


  def refresh_confirmations 
  
Rails.logger.info "DBG:TRACK_CONFIRMS: refresh_confirmations check #{deposit.txid}"
  
  if deposit.currency == 'btc'
  # true parameter is to get watchonly address in details
  raw = CoinRPC[deposit.currency].gettransaction(txid, true)
		Rails.logger.info "DBG:TRACK_CONFIRMS: confirmations field update  #{deposit.txid}"
    self.confirmations = raw[:confirmations]
    save!
  end
  
   if deposit.currency == 'trx'
  
	   rawb = open('https://apilist.tronscan.org/api/block/latest').read 
		rawb = JSON.parse(rawb)
		rawb.symbolize_keys!
		presentBlockNumber = rawb[:number]
	   
		raw = open('https://apilist.tronscan.org/api/transaction-info?hash='+txid).read 
		raw = JSON.parse(raw)
		Rails.logger.info "DBG1: Entered trx block #{raw.inspect}"
		raw.symbolize_keys!		
        blockNumber = raw[:block]
        confirmations = presentBlockNumber - blockNumber
       
    self.confirmations = confirmations
    save!
  end
  
  if deposit.currency == 'usdt'
  
	   rawb = open('https://apilist.tronscan.org/api/block/latest').read 
		rawb = JSON.parse(rawb)
		rawb.symbolize_keys!
		presentBlockNumber = rawb[:number]
	   
		raw = open('https://apilist.tronscan.org/api/transaction-info?hash='+txid).read  
		raw = JSON.parse(raw)
		Rails.logger.info "DBG1: Entered trx block #{raw.inspect}"
		raw.symbolize_keys!		
        blockNumber = raw[:block]
        confirmations = presentBlockNumber - blockNumber
       
    self.confirmations = confirmations
    save!
  end
  
 
  
   
    # follow the same code ad deposit_coin worker to update confirmations
    # this routine shd handle all coins refresh confirmations  
    if deposit.currency == 'eth'   
	    ##Rails.logger.info "DBG: ERC:refresh confirmation called "
	    raw = CoinRPC[deposit.currency].eth_getTransactionByHash(txid)
	    raw.symbolize_keys!
	    blockNumber = raw[:blockNumber].to_i(16)
	    presentBlockNumber = CoinRPC["eth"].eth_blockNumber.to_i(16)    
	    return unless blockNumber and presentBlockNumber 
	    confirmations =  presentBlockNumber - blockNumber       
	  	##Rails.logger.info "DBG: ERC: deposit.currency #{deposit.currency} confirmations  #{confirmations} Blocknumbers: #{presentBlockNumber} #{blockNumber} "  	
	    self.confirmations = confirmations
	    save!
    end 
    
    if deposit.currency == 'erc' || deposit.currency == 'xyz'  || deposit.currency == 'abc'  || deposit.currency == 'p2p'      
	    ##Rails.logger.info "DBG: ERC:refresh confirmation called "
	    raw = CoinRPC[deposit.currency].eth_getTransactionReceipt(txid)
	    raw.symbolize_keys!
	    raw = raw[:logs].first        
	    blockNumber= raw.dig("blockNumber").to_i(16)
	    presentBlockNumber = CoinRPC[deposit.currency].eth_blockNumber.to_i(16)    
	    return unless blockNumber and presentBlockNumber 
	    confirmations =  presentBlockNumber - blockNumber       
	  	##Rails.logger.info "DBG: ERC: deposit.currency #{deposit.currency} confirmations  #{confirmations} Blocknumbers: #{presentBlockNumber} #{blockNumber} "  	
	    self.confirmations = confirmations
	    save!
    end 
    
  end

def deposit_accept
    if deposit.may_accept?
      deposit.accept! 
    end
  end
  def deposit_confirm
      deposit.check! 
  end

  private

  def sync_update
    if self.confirmations_changed?
      #::Pusher["private-#{deposit.member.sn}"].trigger_async('deposits', { type: 'update', id: self.deposit.id, attributes: {confirmations: self.confirmations}})
      puts "Not sending for now"
    end
  end
end
