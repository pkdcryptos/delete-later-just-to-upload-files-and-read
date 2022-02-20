module APIv1
  class Members < Grape::API  
    helpers ::APIv1::NamedParams
	#before { authenticate! }
	
desc 'myallorders', scopes: %w(history trade)
params do
	use :auth, :who
	optional :order_by, type: String, values: %w(asc desc), default: 'desc', desc: "If set, returned orders will be sorted in specific order, default to 'asc'."
	optional :page,  type: Integer, default: 1, desc: "Specify the page of paginated results."
	optional :limit, type: Integer, default: 1000, range: 1..1000, desc: "Limit the number of returned orders, default to 100."
	optional :start_at, type: String
	optional :end_at, type: String
	optional :direction, type: String
	optional :baseAsset, type: String
	optional :quoteAsset, type: String
	optional :hideCancel, type: String
end
get "/myallorders" do
	start_at = params[:start_at]
	end_at = params[:end_at]
	if end_at!=''
		end_at = end_at.to_i + 86400*1000
	end	
	#Rails.logger.info "DBG: myallorders:  start_at: #{start_at},#{Time.at(start_at.to_i/1000).to_datetime},end_at: #{end_at},#{Time.at(end_at.to_i/1000).to_datetime},direction: #{params[:direction]},baseAsset: #{params[:baseAsset]},quoteAsset: #{params[:quoteAsset]},hideCancel: #{params[:hideCancel]},order_by: #{params[:order_by]}, page: #{params[:page]}, limit: #{params[:limit]}"
	orders = current_user.orders
		.order(order_param)
	orders = orders.where('created_at > ?',Time.at(start_at.to_i/1000).to_datetime) if start_at !=''
	orders = orders.where('created_at < ?', Time.at(end_at.to_i/1000).to_datetime) if end_at !=''
	orders = orders.where('state <> ?', 0) if params[:hideCancel]!=''
	orders = orders.where(type: 'OrderAsk') if params[:direction]=='SELL'
	orders = orders.where(type: 'OrderBid') if params[:direction]=='BUY'
	if params[:baseAsset]!=''
		currencyDownCase = params[:baseAsset].to_s.downcase		
		curr = Currency.find_by_code(currencyDownCase)
		if (curr)
			orders = orders.where(ask: curr[:id]) 
		end
	end
	if params[:quoteAsset]!=''
		currencyDownCase = params[:quoteAsset].to_s.downcase		
		curr = Currency.find_by_code(currencyDownCase)
		if (curr)
			orders = orders.where(bid: curr[:id]) 
		end
	end
	
	raise OrdersNotFoundError unless orders
	totalValue = orders.size
	totalCollection = [{ "total":  totalValue }]
	#Rails.logger.info "DBG: myallorders:  totalValue: #{totalValue}"
	
	orders=orders  
		.page(params[:page])
		.per(params[:limit])
	present [
	"totalEntity": totalCollection, "allordersEntity": orders
	], with: APIv1::Entities::Allorders 
end

desc 'myopenorders', scopes: %w(history trade)
params do
  use :auth, :who
  optional :order_by, type: String, values: %w(asc desc), default: 'desc', desc: "If set, returned orders will be sorted in specific order, default to 'asc'."
  optional :limit, type: Integer, default: 500, range: 1..1000, desc: "Limit the number of returned orders, default to 100."
end
get "/myopenorders" do
	orders = current_user.orders.where(ord_type: 'limit')
		.order(order_param)
		.with_state('wait')
		.limit(params[:limit])
	raise OrdersNotFoundError unless orders
	present orders, with: APIv1::Entities::Order
end


desc 'myallorders24h', scopes: %w(history trade)
params do
	use :auth, :who
	optional :order_by, type: String, values: %w(asc desc), default: 'desc', desc: "If set, returned orders will be sorted in specific order, default to 'asc'."
	optional :limit, type: Integer, default: 1000, range: 1..1000, desc: "Limit the number of returned orders, default to 100."
end
get "/myallorders24h" do
	#Sending latest 10 to show on the trade page. .limit(params[:limit]) is replaced by .limit(10)
	# disabled .where('created_at > ?', start_at) 		.where('state <> ?', 100)		
	start_at = DateTime.now.ago(60 * 60 * 24)
	orders = current_user.orders
	orders = orders
		.where('state <> ?', 100)
		.order(order_param)
		.limit(10)
	raise OrdersNotFoundError unless orders
	present orders, with: APIv1::Entities::Order
end

desc 'usertrades'
params do
	use :auth, :who
	optional :page,  type: Integer, default: 1, desc: "Specify the page of paginated results."
	optional :limit, type: Integer, default: 1000, desc: "Limit the number of returned orders, default to 100."
end
get "/usertrades" do
	start_at = params[:start_at]
	end_at = params[:end_at]
	if end_at!=''
		end_at = end_at.to_i + 86400*1000
	end	
	#Rails.logger.info "DBG: usertrades:  start_at: #{start_at},#{Time.at(start_at.to_i/1000).to_datetime},end_at: #{end_at},#{Time.at(end_at.to_i/1000).to_datetime},direction: #{params[:direction]},baseAsset: #{params[:baseAsset]},quoteAsset: #{params[:quoteAsset]}, page: #{params[:page]}, limit: #{params[:limit]}"
	
	trades = Trade.where('bid_member_id = ? OR ask_member_id = ?', current_user.id, current_user.id)
	
	
	trades = trades.where('tradetime > ?',start_at) if start_at !=''
	trades = trades.where('tradetime < ?', end_at) if end_at !=''
	trades = trades.where(ask_member_id: current_user.id) if params[:direction]=='SELL'
	trades = trades.where(bid_member_id: current_user.id) if params[:direction]=='BUY'
	trades = trades.where(baseAsset: params[:baseAsset].to_s.downcase) if params[:baseAsset] != ''
	trades = trades.where(quoteAsset: params[:quoteAsset].to_s.downcase) if params[:quoteAsset] != ''

	
	totalValue = trades.size
	totalCollection = [{ "total":  totalValue }]
	trades = trades
		.page(params[:page])
		.per(params[:limit])
	present [
	"totalEntity": totalCollection, "usertradesEntity": trades
	], with: APIv1::Entities::Usertrades
end


desc 'usertradeorderdetail'
params do
	use :auth, :who
	requires :orderId, type: String
	optional :page,  type: Integer, default: 1, desc: "Specify the page of paginated results."
	optional :limit, type: Integer, default: 1000, desc: "Limit the number of returned orders, default to 100."
end
get "/usertradeorderdetail" do
	#Rails.logger.info "DBG: usertradeorderdetail:  orderId: #{params[:orderId]}, page: #{params[:page]}, limit: #{params[:limit]}"
	#Rails.logger.info "DBG: usertradeorderdetail:  orderId: #{params[:orderId]}, page: #{params[:page]}, limit: #{params[:limit]}"
	order = Order.find params[:orderId]
	trades = order.trades
	totalValue = order.trades_count
	totalCollection = [{ "total":  totalValue }]
	trades = trades
		.page(params[:page])
		.per(params[:limit])
	present [
	"totalEntity": totalCollection, "usertradeorderdetailEntity": trades
	], with: APIv1::Entities::Usertradeorderdetail
end


desc 'Get new address'
params do
	use :auth, :address, :who
end
post "/getnewaddress" do
	begin
	member = Member.find_by_id params[:id]
	currency = params[:currency]
	currencyUpperCase = currency.to_s.upcase
	currencyDownCase = currency.to_s.downcase
	curr = Currency.find_by_code(currencyDownCase)
	enableCharge = curr.getasset_info[:enableCharge]
	if member   
		account = member.get_account(params[:currency])
		if account.payment_addresses.blank?
		    Rails.logger.info "DBG1: payment_addresses blank so create it"
			account.payment_addresses.create(currency: account.currency)
		end
		address = account.payment_addresses.last
		Rails.logger.info "DBG1: address: #{address.inspect}"
		if address.address.blank?	
		    Rails.logger.info "DBG1: address blank"
			address.gen_address if address.address.blank?
		end
		if address.address.include? "_"
			strippedAddress = address.address.split("_")[1]
		else
			strippedAddress = address.address
		end
		msg = {"msg": "success", "address": strippedAddress, "enableCharge": enableCharge , "addressTag": '', "coin": currencyUpperCase, "userId": params[:id]}			
	else
		msg = {"address": '', "addressTag": '', "coin": currencyUpperCase, "userId": ''}
	end
	rescue
	#Rails.logger.info "DBG: Failed to create address: #{$!}"
	Rails.logger.debug $!.backtrace.join("\n")
	raise CreateAddressError, $!
	end
end


desc 'Get your executed trades. Trades are sorted in reverse creation order.', scopes: %w(history)
params do
	use :auth, :market, :trade_filters
end
get "/mytrades" do
	trades = Trade.for_member(
		params[:market], current_user,
		limit: 10, time_to: time_to,
		from: params[:from], to: params[:to],
		order: order_param
		)
	present trades, with: APIv1::Entities::Trade, current_user: current_user
end



desc 'Coin transfer'
params do
	use :auth, :who
	requires :fromCurrency, type: String
	requires :toCurrency, type: String
	requires :funds, type: Float
	requires :toMemberId, type: Integer
	requires :transferType, type: String
end
post "/cointransferescrow" do
begin
	#Rails.logger.info "DBG: cointransfer Received:  #{params[:fromCurrency]} #{params[:toCurrency]} #{params[:funds]} #{params[:toMemberId]} "
	fromCurrency = params[:fromCurrency]
	toCurrency = params[:toCurrency]
	funds = params[:funds].to_f
	transferType = params[:transferType]
	toMemberId = params[:toMemberId]
	memberTo = Member.find_by_id params[:toMemberId]	
			account1 = current_user.get_account(params[:fromCurrency])
			account2 = memberTo.get_account(params[:toCurrency])
			#Rails.logger.info "DBG: cointransfer Received from user:  #{account1.inspect} #{account2.inspect} "
			reasonWithdraw = Account::OLDCODE_INTERNAL_WITHDRAW
			reasonDeposit = Account::OLDCODE_INTERNAL_DEPOSIT
			
			ActiveRecord::Base.transaction do
				account1.lock!.sub_funds funds,  fee: 0, reason: reasonWithdraw, reason1: toMemberId, ref: self
				account2.lock!.plus_funds funds, reason: reasonDeposit, reason1: current_user.id, ref: self
			end
			msg = {"success": 1, "fromCurrency": fromCurrency,  "toCurrency": toCurrency, "funds": funds}      
			msg	
	rescue
	raise CoinTransferError, $!
end
end

desc 'Coin transfer'
params do
	use :auth, :who
	requires :fromCurrency, type: String
	requires :toCurrency, type: String
	requires :funds, type: Float
	requires :toMemberId, type: Integer
end
post "/cointransferptptrade" do
begin
	#Rails.logger.info "DBG: cointransfer Received:  #{params[:fromCurrency]} #{params[:toCurrency]} #{params[:funds]} #{params[:toMemberId]} "
	fromCurrency = params[:fromCurrency]
	toCurrency = params[:toCurrency]
	funds = params[:funds].to_f
	toMemberId = params[:toMemberId]
	memberTo = Member.find_by_id params[:toMemberId]	
			account1 = current_user.get_account(params[:fromCurrency])
			account2 = memberTo.get_account(params[:toCurrency])
			#Rails.logger.info "DBG: cointransfer Received from user:  #{account1.inspect} #{account2.inspect} "
			reasonWithdraw = Account::OLDCODE_PTP_WITHDRAW
			reasonDeposit = Account::OLDCODE_PTP_DEPOSIT
			ActiveRecord::Base.transaction do
				account1.lock!.sub_funds funds,  fee: 0, reason: reasonWithdraw, reason1: toMemberId, ref: self
				account2.lock!.plus_funds funds, reason: reasonDeposit, reason1: current_user.id, ref: self
			end
			msg = {"success": 1, "fromCurrency": fromCurrency,  "toCurrency": toCurrency, "funds": funds}      
			msg	
	rescue
	raise CoinTransferError, $!
end
end










desc 'Create a Sell/Buy order.', scopes: %w(trade)
params do
	use :auth, :market, :order, :who
end
post "/orders" do
	begin
	raise DisabledAccessKeyBPIError if current_user.accessCode == 3
	#if it is limit order, check for minOrderValue check
	if params[:ord_type]=='limit'
		totalOrderValue = params[:price].to_f * params[:volume].to_f
		market = Market.find_by_id(params[:market])
		minOrderValue = market.unit_info[:minOrderValue]
		####################
		#warm logic
		allWarmState=Rails.cache.read("ktio:all:warmState")
		warmState=Rails.cache.read("ktio:#{market.id}:warmState")
		if allWarmState=='0' or allWarmState=='1' or warmState=='0' or warmState=='1' 
			raise TradingSuspendedError
		end      
		######################
		#Rails.logger.info "DBG: minOrderValue check: price: #{params[:price]}, volume: #{params[:volume]}, totalOrderValue: #{totalOrderValue} , minOrderValue: #{minOrderValue}"
		if minOrderValue.to_f > totalOrderValue.to_f
			raise MinOrderValueError, minOrderValue
		end
	end
	
	order = create_order params
	present order, with: APIv1::Entities::Order
	rescue
	Rails.logger.debug $!.backtrace.join("\n")
	raise GeneralError, $!
	end 
end


desc 'Cancel an order.', scopes: %w(trade)
params do
	use :auth, :order_id, :who
end
post "/order/delete" do
	
	#Rails.logger.info "DBG: Cancel order #{params[:id]} "
	raise DisabledAccessKeyBPIError if current_user.accessCode == 3
	####################
	#warm logic
	allWarmState=Rails.cache.read("ktio:all:warmState")
	if allWarmState=='0' 
		raise CancelOrderSuspendedError
	end      
	######################
	begin
		order = current_user.orders.where(ord_type: 'limit').find(params[:id])
		#Rails.logger.info "DBG: Cancel order #{order.inspect} "
		####################
		#warm logic
		warmState=Rails.cache.read("ktio:#{order.currency}:warmState")
		if warmState=='0' 
			raise CancelOrderSuspendedError
		end      
		######################
		Ordering.new(order).cancel
		present order, with: APIv1::Entities::Order
	rescue
		raise CancelOrderError, $!
	end
end


desc 'Cancel all my orders.', scopes: %w(trade)
params do
	use :auth, :who
	optional :isStopLimit, type: Integer
	optional :market, type: String
end
post "/orders/clear" do
	raise DisabledAccessKeyBPIError if current_user.accessCode == 3
	####################
	#warm logic
	allWarmState=Rails.cache.read("ktio:all:warmState")
	if allWarmState=='0'
	raise CancelOrderSuspendedError
	end      
	######################
	begin
		#get all limit pending orders
		orders = current_user.orders.where(ord_type: 'limit').with_state(:wait)  
		if params[:isStopLimit].present?
			orders = orders.where(isStopLimit: params[:isStopLimit])
		end      
		if params[:market].present?
			currency=Market.find_by_id(params[:market]).code
			orders = orders.where(currency: currency)
		end
		orders.each {|o| 
		####################
		#warm logic
		warmState=Rails.cache.read("ktio:#{o.currency}:warmState")
		if warmState=='0' 
			raise CancelOrderSuspendedError
		end      
		######################
		Ordering.new(o).cancel 
		}
		present orders, with: APIv1::Entities::Order
	rescue
		raise CancelOrderError, $!
	end
end
	

desc 'Get your profile and accounts info.', scopes: %w(profile)
params do
	use :auth, :who
	requires :currency, type: String
end
post "/myasset" do
	account = current_user.get_account(params[:currency])
	account
end

desc 'POSTMASTER TESTS: get_my_deposits_from_postmaster'
params do
	use :auth, :who
	optional :rows, type: Integer, range: 1..100, default: 3, desc: "Set result limit."
	optional :page,  type: Integer, default: 1, desc: "Specify the page of paginated results."
end
post "/get_my_deposits_from_postmaster" do
	current_user = Member.find_by_id 1
	Rails.logger.info "DBG: current_user #{current_user} "
	#present current_user, with: APIv1::Entities::Member
	
	# msg={"msg":"PONG2", "current_user": current_user}
	# msg
	
	totalValue = current_user.deposits.limit(100).recent.size
	totalCollection = [{ "total":  totalValue }]
	deposits = current_user.deposits.limit(100).recent
		.page(params[:page])
		.per(params[:rows])
	present [
	"totalEntity": totalCollection, "depositsEntity": deposits
	], with: APIv1::Entities::Moneylogdeposits 
	
end


desc 'POSTMASTER TESTS: create_a_deposit_from_postmaster'
params do
	use :auth, :who
	optional :howmany,  type: Integer, default: 1, desc: "howmany dummy orders ?"
end
post "/create_a_deposit_from_postmaster" do
	current_user = Member.find_by_id 1
	Rails.logger.info "DBG: current_user #{current_user}   "
	account = current_user.get_account('btc')
	Rails.logger.info "DBG: account #{account.inspect}   "
	######################
	params[:howmany].times do |i|
      timestamp = Time.now.to_i
      txid = "mock#{SecureRandom.hex(32)}"
      txout = 0
      address = account.payment_address.address	  
			Rails.logger.info "DBG: address #{address.inspect}   "
	  amount = rand(100000)
      confirmations = 100
      receive_at = Time.now
      channel = DepositChannel.find_by_key account.currency_obj.key
      Rails.logger.info "DBG: channel #{channel.inspect}   "
      ActiveRecord::Base.transaction do
        tx = PaymentTransaction.create!(
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


	
desc 'Get your profile and accounts info.', scopes: %w(profile)
params do
	use :auth, :who
end
post "/myassets" do
	present current_user, with: APIv1::Entities::Member
end


desc 'Get your profile and accounts info.'
params do
	use :auth, :who
	requires :currency, type: String, values: Currency.all.map(&:code), desc: "Currency value contains  #{Currency.all.map(&:code).join(',')}"
end
post "/getaddresslist" do
	fundsources = current_user.fund_sources.with_currency(params[:currency])
	present fundsources, with: APIv1::Entities::Fundsource
end


desc 'Get trade fees'
params do
	use :auth, :who, :market
end
get "/usertradefee" do
#Rails.logger.info "DBG: usertradefee #{params[:market]} "
	utfmarket = {}
	Market.all.inject({}) do |h, m|
		if m.id == params[:market]
			utfmarket=m.tradefee_info 
		end
	end 
	utfmarket[:userId]=current_user.id
	utfmarket       
end


desc 'Get your orders, results is paginated.', scopes: %w(history trade)
params do
use :auth, :who
	optional :state, type: String,  default: 'done', values: Order.state.values, desc: "Filter order by state, default to 'wait' (active orders)."
	optional :limit, type: Integer, default: 3, range: 1..1000, desc: "Limit the number of returned orders, default to 100."
	optional :page,  type: Integer, default: 1, desc: "Specify the page of paginated results."
	optional :order_by, type: String, values: %w(asc desc), default: 'desc', desc: "If set, returned orders will be sorted in specific order, default to 'asc'."
end
get "/paginate" do
	orders = current_user.orders
		.order(order_param)
		.with_state(params[:state])
		.page(params[:page])
		.per(params[:limit])
	present orders, with: APIv1::Entities::Order
end



   ############# not in use list 
    
     desc 'Apply withdraw'
params do
	use :auth, :who
	requires :currency, type: String,  desc: "currency to withdraw"
	requires :amount, type: String,  desc: "amount to withdraw"
	requires :coinaddr, type: String,  desc: "address to withdraw"
	optional :name, type: String,  desc: "name of fund source"
end
post "/applywithdraw" do
	begin
    raise DisabledAccessKeyBPIError if current_user.accessCode == 3
    
    #address validation , mostly do the regex
    curr = Currency.find_by_code(params[:currency])
    coinAddrLength = curr.coinAddrLength
    coinAddrSample = curr.coinAddrSample
    coinAddrTestChars = curr.coinAddrTestChars
    Rails.logger.info "DBG Params: #{params[:currency]}, #{params[:amount]}, #{params[:coinaddr]}, #{params[:name]} #{coinAddrLength} #{coinAddrSample} #{coinAddrTestChars}" 
    coinaddrTest=params[:coinaddr]
    coindaddrTestDelete = coinaddrTest.delete(coinAddrTestChars)
    usersCoinAddrLength = params[:coinaddr].length
    #if coindaddrTestDelete != '' || usersCoinAddrLength != coinAddrLength 
	if false
        msg = "address validation failed #{coindaddrTestDelete} #{usersCoinAddrLength} #{coinAddrLength}"
    	msg = "Address validation failed"
    	{"success": false, "msg": msg}
    else
    		Rails.logger.info "Regex success"
			# create fund source from address and name
			fund_sources = current_user.fund_sources.where(uid: params[:coinaddr]).with_currency(params[:currency])
			if fund_sources.size > 0
			else
				Rails.logger.info "DBG: fund_sources not found"
				fund_source_params = {"currency"=> params[:currency], "uid"=> params[:coinaddr] , "extra"=> params[:name]}	
				new_fund_source = current_user.fund_sources.new fund_source_params
				new_fund_source.save     
			end
			withdraw_token=SecureRandom.urlsafe_base64(30).tr('_-', 'xx')
			if withdraw_token.size > 10 &&  (current_user.accessCode==1 || current_user.accessCode==2)
				# prepare fee and deduct from sum, check if amount is as per min     
				assetinfo = Currency.find_by_code(params[:currency].downcase).getasset_info   
				transactionFee = assetinfo[:transactionFee]
				minProductWithdraw = assetinfo[:minProductWithdraw]
				Rails.logger.info "DBG: assetinfo: #{assetinfo.inspect} transactionFee: #{transactionFee} minProductWithdraw: #{minProductWithdraw}"
				if params[:amount].to_f >= minProductWithdraw.to_f  
					withdraw_params = {"fund_uid"=> params[:coinaddr]	,"fund_extra"=> params[:name]	, "member_id"=> current_user.id, "currency"=> params[:currency], "sum"=>  params[:amount], "withdraw_token" => withdraw_token, "validated" => 1}     
					selfControllerName = "withdraws/#{params[:currency]}coin" 
					if params[:currency]=='btc'
						selfControllerName = "withdraws/Satoshi" 
					end
					if params[:currency]=='eth'
						selfControllerName = "withdraws/Ether" 
					end
					@withdraw = selfControllerName.camelize.constantize.new(withdraw_params)
					Rails.logger.info "DBG: withdraw_params #{withdraw_params}"
					Rails.logger.info "DBG: selfControllerName #{selfControllerName}"
					Rails.logger.info "DBG: selfControllerName.camelize.constantize #{selfControllerName.camelize.constantize}"     
					if @withdraw.save
						@withdraw.submit!
						{"success": true, "id": @withdraw.id}
					else
						{"success": false, "msg": 'Failed'}
					end
				else
					Rails.logger.info "DBG: minProductWithdraw case fail #{minProductWithdraw} #{params[:amount]}"  
					{"success": false, "msg": 'Min withdraw not met'}
				end 
			else
			{"success": false, "msg": 'Withdraw token not created or Access restricted'}
			end 
		end
		rescue
	Rails.logger.debug $!.backtrace.join("\n")
	raise GeneralError, $!
	end 
end
     
      
   desc 'Cancel withdraw'
    params do
      use :auth, :who
      requires :id, type: Integer
	  optional :cancelReason, type: String
    end
    post "/cancelwithdraw" do
	begin
     cancelReason =  params[:cancelReason]
     Withdraw.transaction do
        @withdraw = Withdraw.find(params[:id]).lock!
        if @withdraw.aasm_state == 'submitted' || @withdraw.aasm_state == 'accepted' 
        @withdraw.cancel	
		updated_notes =  Time.now.to_s + ':' + params[:cancelReason] + '<br/>' + @withdraw.notes.to_s
		@withdraw.update_attributes(:notes => updated_notes, :cancelReason => cancelReason)
		@withdraw.save!					  
        {"success":true}   
		
        else
		 {"success":false, "msg": 'This transaction is not in submitted, accepted state'}    
        end
      end
      rescue
	Rails.logger.debug $!.backtrace.join("\n")
	raise GeneralError, $!
	end 
              
    end
	
	desc 'CancelOne withdraw'
    params do
      use :auth, :who
      requires :id, type: Integer
	  optional :cancelReason, type: String
    end
    post "/cancelonewithdraw" do
	begin
     cancelReason =  params[:cancelReason]
     Withdraw.transaction do
        @withdraw = Withdraw.find(params[:id]).lock!
        if @withdraw.aasm_state == 'processing' 
        @withdraw.cancelone	
		updated_notes =  Time.now.to_s + ':' + params[:cancelReason] + '<br/>' + @withdraw.notes.to_s
		@withdraw.update_attributes(:notes => updated_notes, :cancelReason => cancelReason)
		@withdraw.save!					  
        {"success":true}   
		
        else
		 {"success":false, "msg": 'This transaction is not in processing state'}    
        end
      end
       rescue
	Rails.logger.debug $!.backtrace.join("\n")
	raise GeneralError, $!
	end  
              
    end

    
   desc 'Process withdraw'
    params do
      use :auth, :who
      requires :id, type: Integer
	  optional :processReason, type: String
    end
    post "/processwithdraw" do
	begin
     processReason =  params[:processReason]
     Withdraw.transaction do
        @withdraw = Withdraw.find(params[:id]).lock!
        if @withdraw.aasm_state == 'accepted'
		@withdraw.process	
		updated_notes =  Time.now.to_s + ':' + params[:processReason] + '<br/>' + @withdraw.notes.to_s
		@withdraw.update_attributes(:notes => updated_notes)
		@withdraw.save!					  
        {"success":true}
        
        else
		 {"success":false, "msg": 'This transaction is not in accepted state'}       
        end
      end
      rescue
	Rails.logger.debug $!.backtrace.join("\n")
	raise GeneralError, $!
	end   
              
    end
    
    
     desc 'getapis'
    params do
       use :auth, :who
    end
    post "/getapis" do
	apitokens =	 current_user.api_tokens
  present apitokens, with: APIv1::Entities::Apitoken
    
    
    end
    
   
    
    
    desc 'getwithdrawaddresslist'
    params do
      use :auth
    end
    post "/getwithdrawaddresslist" do
	fundsources =	 current_user.fund_sources
  present fundsources, with: APIv1::Entities::Fundsource
    end
    
     desc 'Insert address whitelist'
    params do
      use :auth, :who
      requires :currency, type: String,  desc: "currency to withdraw"
      requires :coinaddr, type: String,  desc: "address to withdraw"
      requires :name, type: String,  desc: "name of fund source"
    end
    post "/insertaddresswhitelist" do
    
     # create fund source from address and name
      fund_sources = current_user.fund_sources.where(uid: params[:coinaddr]).with_currency(params[:currency])
      if fund_sources.size > 0
      {"success": false, "msg": "Address already exists"}
      else
      fund_source_params = {"currency"=> params[:currency], "uid"=> params[:coinaddr] , "extra"=> params[:name]}	
      new_fund_source = current_user.fund_sources.new fund_source_params
      new_fund_source.save 
      {"success": true, "id": new_fund_source.id}    
      end
  
      
    end
    
     
    
    

    
    
desc 'myallorders24hdone', scopes: %w(history trade)
params do
  use :auth, :who
  optional :order_by, type: String, values: %w(asc desc), default: 'asc', desc: "If set, returned orders will be sorted in specific order, default to 'asc'."
end
get "/myallorders24hdone" do
start_at = DateTime.now.ago(60 * 60 * 24)
  orders = current_user.orders
  orders = orders
  .where('created_at > ?', start_at)
  	.order(order_param)
raise OrdersNotFoundError unless orders
  present orders, with: APIv1::Entities::Order, type: :full

end

desc 'saveapi'
    params do
      use :auth, :who
      requires :apiName, type: String
    end
    post "/saveapi" do
    
    apiEmailVerifyToken = SecureRandom.urlsafe_base64(30).tr('_-', 'xx')
    
      apitoken = current_user.api_tokens.create!(label: params[:apiName], apiEmailVerifyToken: apiEmailVerifyToken, scopes: 'all')
      out = {"success": true, "id":apitoken.id,  "apiEmailVerifyToken": apitoken.apiEmailVerifyToken}
      out
    end
     
    
    
    
   

 
   
     
############# not in use list 
    
  end
end