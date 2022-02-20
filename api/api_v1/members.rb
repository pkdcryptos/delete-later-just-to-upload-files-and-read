require_relative 'validations'
module APIv1
  class Members < Grape::API  
    helpers ::APIv1::NamedParams
	#before { authenticate! }

    desc 'Get your profile and accounts info.'
    params do
      use :auth
    end
    post "/membersme" do 
			current_user = Member.find_by_id 1
      present current_user, with: APIv1::Entities::Member
    end
		
		
		
desc 'Get your deposits history.'
params do
use :auth, :who
	optional :rows, type: Integer, range: 1..100, default: 30, desc: "Set result limit."
	optional :page,  type: Integer, default: 1, desc: "Specify the page of paginated results."
	end
post "/mydeposits" do
	current_user = Member.find_by_id 1
	totalValue = current_user.deposits.limit(100).recent.size
	totalCollection = [{ "total":  totalValue }]
	deposits = current_user.deposits.limit(100).recent
		.page(params[:page])
		.per(params[:rows])
	present ["totalEntity": totalCollection, "depositsEntity": deposits], with: APIv1::Entities::Moneylogdeposits 
end

		
desc 'Get your withdraws history.'
params do
	use :auth, :who
	optional :rows, type: Integer, range: 1..100, default: 30, desc: "Set result limit."
	optional :page,  type: Integer, default: 1, desc: "Specify the page of paginated results."
end
post "/mywithdraws" do
current_user = Member.find_by_id 1
	totalValue = current_user.withdraws.limit(100).recent.size
	totalCollection = [{ "total":  totalValue }]
	withdraws = current_user.withdraws.limit(100).recent
		.page(params[:page])
		.per(params[:rows])
	present [	"totalEntity": totalCollection, "withdrawsEntity": withdraws	], with: APIv1::Entities::Moneylogwithdraws
	
end
		
desc 'POSTMASTER TESTS: get_my_deposits_from_postmaster'
params do
	use :auth, :who
	optional :rows, type: Integer, range: 1..100, default: 30, desc: "Set result limit."
	optional :page,  type: Integer, default: 1, desc: "Specify the page of paginated results."
end
post "/get_my_deposits_from_postmaster" do
	current_user = Member.find_by_id 1
	Rails.logger.info "DBG: current_user #{current_user} "
	
	totalValue = current_user.deposits.limit(100).recent.size
	Rails.logger.info "DBG: totalValue #{totalValue} "
	totalCollection = [{ "total":  totalValue }]
	Rails.logger.info "DBG: totalCollection #{totalCollection} "
	deposits = current_user.deposits.limit(100).recent
		.page(params[:page])
		.per(params[:rows])
	Rails.logger.info "DBG: deposits #{deposits} "
	present ["totalEntity": totalCollection, "depositsEntity": deposits], with: APIv1::Entities::Moneylogdeposits 
	
	
	
end


desc 'POSTMASTER TESTS: create_a_deposit_from_postmaster'
params do
	use :auth, :who
	optional :howmany,  type: Integer, default: 1, desc: "howmany dummy orders ?"
	requires :txid
end
post "/create_a_deposit_from_postmaster" do
	current_user = Member.find_by_id 1
	Rails.logger.info "DBG: current_user #{current_user}   "
	account = current_user.get_account('btc')
	Rails.logger.info "DBG: account #{account.inspect}   "
	######################
	params[:howmany].times do |i|
      timestamp = Time.now.to_i
      txid = params[:txid]
      txout = 0
      address = account.payment_address.address	  
			Rails.logger.info "DBG: address #{address.inspect}   "
	  amount = rand(100000)
      confirmations = 100
      receive_at = Time.now
      channel = DepositChannel.find_by_key account.currency_obj.key
      Rails.logger.info "DBG: channel #{channel.inspect}   "
      ActiveRecord::Base.transaction do
        tx = PaymentTransaction::Normal.create!(
          txid: txid,
          txout: txout,
          address: address,
          amount: amount,
          confirmations: confirmations,
          receive_at: receive_at,
          currency: channel.currency
        )
Rails.logger.info "DBG: tx #{tx.inspect}   "
        deposit = channel.kls.create!(
          payment_transaction_id: tx.id,
          txid: tx.txid,
          txout: tx.txout,
          amount: tx.amount,
          member: tx.member,
          account: tx.account,
          currency: tx.currency,
          confirmations: tx.confirmations
        )
Rails.logger.info "DBG: deposit #{deposit.inspect}   "
        deposit.submit!
        deposit.accept!
				
       
     
				
				
      end
    end
		######################
	 current_user
end

		

  end
end
