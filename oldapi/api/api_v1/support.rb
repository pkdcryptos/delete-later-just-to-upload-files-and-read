module APIv1
  class Support < Grape::API
    helpers ::APIv1::NamedParams
    before { authenticate! }

desc 'Get account examine display'
params do
	use :auth, :who	
	requires :memberId, type: String	
	requires :currency, type: String
	

end
post "/examinedisplay" do
begin
	memberId = params[:memberId]	
	currency = params[:currency]	
	member = Member.find_by_id params[:memberId]
	account = member.get_account(params[:currency])
	account.examine_display
	rescue
	raise GeneralError, $!
end
end
	
desc 'Create trade record'
params do
	use :auth, :who
	requires :tradeId, type: String
	requires :offerId, type: String
	requires :sellerMemberId, type: String
	requires :sellerNickname, type: String
	requires :buyerMemberId, type: String
	requires :buyerNickname, type: String
	requires :offerMemberId, type: String
	requires :status, type: String
	requires :noOfCoins, type: Float
	requires :price, type: Float
	requires :offerPrice, type: Float
	requires :coinMarketPrice, type: Float
	requires :fiatExchangePrice, type: Float
	requires :noOfCoinsInBTC, type: Float
	requires :fromCurrency, type: String
	requires :toCurrency, type: String
	requires :offerType, type: String
	requires :coinId, type: String
	requires :paymentMethod, type: String
	requires :preferredCurrency, type: String
	requires :escrowFeePercent, type: Float
	requires :escrowFee, type: Float

end
post "/createtrade" do
begin
	tradeId = params[:tradeId]
	offerId = params[:offerId]
	sellerMemberId = params[:sellerMemberId]
	sellerNickname = params[:sellerNickname]
	buyerMemberId = params[:buyerMemberId]
	buyerNickname = params[:buyerNickname]
	offerMemberId = params[:offerMemberId]
	paymentMethod = params[:paymentMethod]
	status = params[:status]
	noOfCoins = params[:noOfCoins].to_f
	price = params[:price]
	offerPrice = params[:offerPrice]
	coinMarketPrice = params[:coinMarketPrice]
	fiatExchangePrice = params[:fiatExchangePrice]
	noOfCoinsInBTC = params[:noOfCoinsInBTC]
	
	escrowFee = params[:escrowFee].to_f

	
	
	fromCurrency = params[:fromCurrency]
	toCurrency = params[:toCurrency]
	member = Member.find_by_id params[:sellerMemberId]
	memberAdmin = Member.find_by_id 1
	account1 = member.get_account(params[:fromCurrency])
	account2 = member.get_account(params[:toCurrency])
	accountAdmin = memberAdmin.get_account(params[:fromCurrency])
	Rails.logger.info "DBGTRADE: coinTrade request Received:  tradeId #{tradeId} offerId #{offerId} sellerMemberId #{sellerMemberId} sellerNickname #{sellerNickname}  buyerMemberId #{buyerMemberId}  buyerNickname #{buyerNickname}  offerMemberId #{offerMemberId}  status #{status}  noOfCoins #{noOfCoins}   price #{price}   coinMarketPrice #{coinMarketPrice}   fiatExchangePrice #{fiatExchangePrice}   noOfCoinsInBTC #{noOfCoinsInBTC}   escrowFee #{escrowFee}  fromCurrency #{fromCurrency}  toCurrency #{toCurrency}  "
	ActiveRecord::Base.transaction do
				account1.lock!.sub_funds noOfCoins,  fee: 0, reason: Account::PTP_CREATED_TRADE, reason1: tradeId, ref: self
				account2.lock!.plus_funds noOfCoins, reason: Account::PTP_CREATED_TRADE, reason1: tradeId, ref: self
				account1.lock!.sub_funds escrowFee,  fee: 0, reason: Account::PTP_CREATED_TRADE, reason1: tradeId, ref: self
				accountAdmin.lock!.plus_funds escrowFee, reason: Account::PTP_CREATED_TRADE, reason1: tradeId, ref: self
				mtrade = Mtrade.create(tradeId: tradeId, offerId: offerId, sellerMemberId: sellerMemberId, sellerNickname: sellerNickname, buyerMemberId: buyerMemberId, buyerNickname: buyerNickname, offerMemberId: offerMemberId, paymentMethod: paymentMethod, status: status, noOfCoins: noOfCoins, price: price, offerPrice: offerPrice, coinMarketPrice: coinMarketPrice, fiatExchangePrice: fiatExchangePrice, noOfCoinsInBTC: noOfCoinsInBTC, offerType:params[:offerType], coinId:params[:coinId], preferredCurrency:params[:preferredCurrency], escrowFeePercent:params[:escrowFeePercent].to_f, escrowFee:params[:escrowFee].to_f )
	end
	msg = {"success": 1, "tradeId": tradeId}      
	msg	
	rescue
	raise CoinTransferError, $!
end
end

desc 'Dispute resolve'
params do
	use :auth, :who
	requires :tradeId, type: String
	requires :transferType, type: String
	requires :fromMemberId, type: String
	requires :toMemberId, type: String
	requires :noOfCoins, type: Float
	requires :fromCurrency, type: String
	requires :toCurrency, type: String	
	requires :escrowFee, type: Float
	requires :feeRevert, type: Integer
	
	
end
post "/disputeresolve" do
begin
	tradeId = params[:tradeId]
	transferType = params[:transferType]
	fromMemberId = params[:fromMemberId]
	toMemberId = params[:toMemberId]
	noOfCoins = params[:noOfCoins].to_f	
	escrowFee = params[:escrowFee].to_f
	fromCurrency = params[:fromCurrency]
	toCurrency = params[:toCurrency]
	feeRevert = params[:feeRevert]
	
	
	Rails.logger.info "DBGTRADE: disputeresolve request Received:  tradeId #{tradeId} fromMemberId #{fromMemberId} toMemberId #{toMemberId}   noOfCoins #{noOfCoins}   escrowFee #{escrowFee}  fromCurrency #{fromCurrency}  toCurrency #{toCurrency}   feeRevert #{feeRevert}  "
	
	
	memberFrom = Member.find_by_id fromMemberId
	memberTo = Member.find_by_id toMemberId
	memberAdmin = Member.find_by_id 1
	accountFrom = memberFrom.get_account(params[:fromCurrency])
	accountTo = memberTo.get_account(params[:toCurrency])
	accountAdmin = memberAdmin.get_account(params[:toCurrency])
	
	ActiveRecord::Base.transaction do
				if transferType!='asis'
					accountFrom.lock!.sub_funds noOfCoins,  fee: 0, reason: Account::PTP_DISPUTE_RESOLVED, reason1: tradeId, ref: self
					accountTo.lock!.plus_funds noOfCoins, reason: Account::PTP_DISPUTE_RESOLVED, reason1: tradeId, ref: self
					if feeRevert==1 
					accountAdmin.lock!.sub_funds escrowFee,  fee: 0, reason: Account::PTP_DISPUTE_RESOLVED, reason1: tradeId, ref: self
					accountTo.lock!.plus_funds escrowFee, reason: Account::PTP_DISPUTE_RESOLVED, reason1: tradeId, ref: self
					end
				end
				mtrade = Mtrade.find_by_tradeId params[:tradeId]
				mtrade.update_attributes(:status => 'Resolved', :disputeResolvedAt => Time.now)
				mtrade.save
	end
	msg = {"success": 1, "tradeId": tradeId}      
	msg	
	rescue
	raise CoinTransferError, $!
end
end


desc 'disputeresolvenotransfers'
params do
	use :auth, :who
	requires :tradeId, type: String
	
	

end
post "/disputeresolvenotransfers" do
begin
	tradeId = params[:tradeId]

	
	Rails.logger.info "DBGTRADE: disputeresolvenotransfers request Received:  tradeId #{tradeId}  "
	
	ActiveRecord::Base.transaction do
				
				mtrade = Mtrade.find_by_tradeId params[:tradeId]
				mtrade.update_attributes(:status => 'Resolved', :disputeResolvedAt => Time.now)
				mtrade.save
	end
	msg = {"success": 1, "tradeId": tradeId}      
	msg	
	rescue
	raise CoinTransferError, $!
end
end



desc 'dispute trade'
params do
	use :auth, :who
	requires :tradeId, type: String
	requires :status, type: String
	requires :sellerMemberId, type: String
	requires :buyerMemberId, type: String
	requires :disputedBy, type: String
	

end
post "/disputetrade" do
begin
	tradeId = params[:tradeId]
	status = params[:status]
	sellerMemberId = params[:sellerMemberId]
	buyerMemberId = params[:buyerMemberId]
	disputedBy = params[:disputedBy]	
	Rails.logger.info "DBGTRADE: disputetrade request Received:  tradeId #{tradeId}  sellerMemberId #{sellerMemberId}  buyerMemberId #{buyerMemberId}  disputedBy #{disputedBy}   status #{status}  "
	ActiveRecord::Base.transaction do
				mtrade = Mtrade.find_by_tradeId params[:tradeId]
				if mtrade.disputedBy == ""				
				memberSeller = Member.find_by_id params[:sellerMemberId]
				memberBuyer = Member.find_by_id params[:buyerMemberId]
				mtrade.update_attributes(:status => 'Disputed', :statusBeforeDispute => status, :disputedBy => disputedBy) 
				memberBuyer.update_attributes(:withdrawDisabled => 1)
				memberSeller.update_attributes(:withdrawDisabled => 1)
				
				end
				mtrade.save
	end
	msg = {"success": 1, "tradeId": tradeId}      
	msg	
	rescue
	raise CoinTransferError, $!
end
end


desc 'Reopen trade'
params do
	use :auth, :who
	requires :tradeId, type: String
	requires :offerId, type: String
	requires :sellerMemberId, type: String
	requires :sellerNickname, type: String
	requires :buyerMemberId, type: String
	requires :buyerNickname, type: String
	requires :offerMemberId, type: String
	requires :status, type: String
	requires :noOfCoins, type: Float
	requires :price, type: Float
	requires :coinMarketPrice, type: Float
	requires :fiatExchangePrice, type: Float
	requires :noOfCoinsInBTC, type: Float
	requires :fromCurrency, type: String
	requires :toCurrency, type: String
	requires :offerType, type: String
	requires :coinId, type: String
	requires :paymentMethod, type: String
	requires :preferredCurrency, type: String
	requires :escrowFeePercent, type: Float
	requires :escrowFee, type: Float

end
post "/reopentrade" do
begin
	tradeId = params[:tradeId]
	offerId = params[:offerId]
	sellerMemberId = params[:sellerMemberId]
	sellerNickname = params[:sellerNickname]
	buyerMemberId = params[:buyerMemberId]
	buyerNickname = params[:buyerNickname]
	offerMemberId = params[:offerMemberId]
	status = params[:status]
	noOfCoins = params[:noOfCoins].to_f
	price = params[:price]
	coinMarketPrice = params[:coinMarketPrice]
	fiatExchangePrice = params[:fiatExchangePrice]
	noOfCoinsInBTC = params[:noOfCoinsInBTC]
	
	escrowFee = params[:escrowFee].to_f

	
	
	fromCurrency = params[:fromCurrency]
	toCurrency = params[:toCurrency]
	member = Member.find_by_id params[:sellerMemberId]
	memberAdmin = Member.find_by_id 1
	account1 = member.get_account(params[:fromCurrency])
	account2 = member.get_account(params[:toCurrency])
	accountAdmin = memberAdmin.get_account(params[:fromCurrency])
	Rails.logger.info "DBGTRADE: reopentrade request Received:  tradeId #{tradeId} offerId #{offerId} sellerMemberId #{sellerMemberId} sellerNickname #{sellerNickname}  buyerMemberId #{buyerMemberId}  buyerNickname #{buyerNickname}  offerMemberId #{offerMemberId}  status #{status}  noOfCoins #{noOfCoins}   price #{price}   coinMarketPrice #{coinMarketPrice}   fiatExchangePrice #{fiatExchangePrice}   noOfCoinsInBTC #{noOfCoinsInBTC}   escrowFee #{escrowFee}  fromCurrency #{fromCurrency}  toCurrency #{toCurrency}  "
	ActiveRecord::Base.transaction do
				mtrade = Mtrade.find_by_tradeId params[:tradeId]
				if mtrade.status == "Cancelled"
				account1.lock!.sub_funds noOfCoins,  fee: 0, reason: Account::PTP_REOPENED_TRADE, reason1: tradeId, ref: self
				account2.lock!.plus_funds noOfCoins, reason: Account::PTP_REOPENED_TRADE, reason1: tradeId, ref: self
				account1.lock!.sub_funds escrowFee,  fee: 0, reason: Account::PTP_REOPENED_TRADE, reason1: tradeId, ref: self
				accountAdmin.lock!.plus_funds escrowFee, reason: Account::PTP_REOPENED_TRADE, reason1: tradeId, ref: self				
				mtrade.update_attributes(:status => 'Pending') 
				end
				mtrade.save
				
	end
	msg = {"success": 1, "tradeId": tradeId}      
	msg	
	rescue
	raise CoinTransferError, $!
end
end



desc 'Cancel trade'
params do
	use :auth, :who
	requires :tradeId, type: String	
	requires :noOfCoins, type: Float	
	requires :fromCurrency, type: String	
	requires :toCurrency, type: String
	requires :sellerMemberId, type: String
	requires :escrowFee, type: Float
	
end
post "/canceltrade" do
begin
	tradeId = params[:tradeId]
	noOfCoins = params[:noOfCoins].to_f	
	fromCurrency = params[:fromCurrency]
	toCurrency = params[:toCurrency]
	sellerMemberId = params[:sellerMemberId]
	
	escrowFee = params[:escrowFee].to_f
	
	member = Member.find_by_id params[:sellerMemberId]
	memberAdmin = Member.find_by_id 1
	account1 = member.get_account(params[:fromCurrency])
	account2 = member.get_account(params[:toCurrency])
	accountAdmin = memberAdmin.get_account(params[:toCurrency])
	
	
	
	
Rails.logger.info "DBGTRADE: cancelTrade request Received: tradeId: #{tradeId} noOfCoins: #{noOfCoins} fromCurrency: #{fromCurrency} toCurrency: #{toCurrency}  sellerMemberId: #{sellerMemberId}  escrowFee: #{escrowFee}   "
	
ActiveRecord::Base.transaction do
				mtrade = Mtrade.find_by_tradeId params[:tradeId]
				if mtrade.status == "Pending"
				account1.lock!.sub_funds noOfCoins,  fee: 0, reason: Account::PTP_CANCELLED_TRADE, reason1: tradeId, ref: self
				account2.lock!.plus_funds noOfCoins, reason: Account::PTP_CANCELLED_TRADE, reason1: tradeId, ref: self
				accountAdmin.lock!.sub_funds escrowFee,  fee: 0, reason: Account::PTP_CANCELLED_TRADE, reason1: tradeId, ref: self
				account2.lock!.plus_funds escrowFee, reason: Account::PTP_CANCELLED_TRADE, reason1: tradeId, ref: self
				mtrade.update_attributes(:status => 'Cancelled')  
				end
mtrade.save
end	

msg = {"success": 1, "tradeId": tradeId}      
	msg	
	rescue
	raise CoinTransferError, $!
end
end



desc 'Escrow release'
params do
	use :auth, :who
	requires :tradeId, type: String	
	requires :noOfCoins, type: Float	
	requires :fromCurrency, type: String	
	requires :toCurrency, type: String
	requires :sellerMemberId, type: String
	requires :buyerMemberId, type: String
	
end
post "/escrowrelease" do
begin
	tradeId = params[:tradeId]
	noOfCoins = params[:noOfCoins].to_f	
	fromCurrency = params[:fromCurrency]
	toCurrency = params[:toCurrency]
	sellerMemberId = params[:sellerMemberId]
	buyerMemberId = params[:buyerMemberId]
	
	memberSeller = Member.find_by_id params[:sellerMemberId]
	memberBuyer = Member.find_by_id params[:buyerMemberId]
	account1 = memberSeller.get_account(params[:fromCurrency])
	account2 = memberBuyer.get_account(params[:toCurrency])
	
	
	
	
		Rails.logger.info "DBGTRADE: escrowrelease request Received: tradeId: #{tradeId} noOfCoins: #{noOfCoins} fromCurrency: #{fromCurrency} toCurrency: #{toCurrency}  sellerMemberId: #{sellerMemberId}  buyerMemberId: #{buyerMemberId}   "
	
ActiveRecord::Base.transaction do
				mtrade = Mtrade.find_by_tradeId params[:tradeId]
				if mtrade.status == "Paid"
				account1.lock!.sub_funds noOfCoins,  fee: 0, reason: Account::PTP_ESCROW_RELEASED, reason1: tradeId, ref: self
				account2.lock!.plus_funds noOfCoins, reason: Account::PTP_ESCROW_RELEASED, reason1: tradeId, ref: self
				mtrade.update_attributes(:status => 'Released')  
				end
mtrade.save
end	

msg = {"success": 1, "tradeId": tradeId}      
	msg	
	rescue
	raise CoinTransferError, $!
end
end




	
desc 'Admin Coin transfer PTP'
params do
	use :auth, :who
	requires :transferCurrency, type: String
	requires :funds, type: Float
	requires :fromMemberId, type: Integer
	requires :toMemberId, type: Integer
end
post "/admintransfer" do
begin
	Rails.logger.info "DBG: admintransfer Received:  #{params[:transferCurrency]} #{params[:fromMemberId]} #{params[:toMemberId]} #{params[:funds]} "
	transferCurrency = params[:transferCurrency]
	funds = params[:funds].to_f
	fromMemberId = params[:fromMemberId]
	toMemberId = params[:toMemberId]
	memberTo = Member.find_by_id params[:toMemberId]
	memberFrom = Member.find_by_id params[:fromMemberId]
	Rails.logger.info "DBG: admintransfer Received:  #{memberFrom.id} #{memberTo.id} "
	
	if memberFrom.id == memberTo.id
		msg = {"success": 0, "msg": "Can not transfer to same user"}      
			msg
	else
	
		account1 = memberFrom.get_account(params[:transferCurrency])
		account2 = memberTo.get_account(params[:transferCurrency])
		#Rails.logger.info "DBG: admintransfer Received with admin:  #{account1.inspect} #{account2.inspect} "
		ActiveRecord::Base.transaction do 
			account1.lock!.sub_funds funds,  fee: 0, reason: Account::ADMIN_TRANSFER, reason1: toMemberId, ref: self
			account2.lock!.plus_funds funds, reason: Account::ADMIN_TRANSFER, reason1: fromMemberId, ref: self
		end
		msg = {"success": 1, "transferCurrency": transferCurrency, "funds": funds}  
		msg	
	end
	
rescue
	raise CoinTransferError, $!
end
end




desc 'Get daemon status.'
params do
	use :auth, :who
end
get "/daemonstatus" do    
	@daemon_statuses = Global.daemon_statuses
end

desc 'Get currency summary.'
params do
	use :auth, :who
end
get "/currencysummary" do    
	@currencies_summary = Currency.all.map(&:summary)
end 



desc 'Get wallet settings'
params do
	use :auth, :who
end
get "/walletget" do    
	assets = []
	Currency.all.each do |currency|
		assets.push(currency.walletControl_info)
	end  
	assets.push({:id => 11111, :assetCode => 'ALL', :assetName => 'ALL',  :enableCharge => Rails.cache.read("ktio:all:enableCharge"), :enableWithdraw => Rails.cache.read("ktio:all:enableWithdraw"), :depositTip => Rails.cache.read("ktio:all:depositTip"), :depositTipLink => Rails.cache.read("ktio:all:depositTipLink")})
	assets
end


desc 'Set walletControl for a given currency'
params do
	use :auth, :who, :asset
	requires :enableCharge, type: String
	requires :enableWithdraw, type: String
	requires :depositTip, type: String
	requires :depositTipLink, type: String
end
get "/walletset/:asset" do
	#Rails.logger.info "DBG: walletset all"
	if params[:asset].downcase=='all'
	
		Currency.all.each do |currency|
			Rails.cache.write "ktio:#{currency.code}:enableCharge", params[:enableCharge]
			Rails.cache.write "ktio:#{currency.code}:enableWithdraw", params[:enableWithdraw]
			Rails.cache.write "ktio:#{currency.code}:depositTip", params[:depositTip]
			Rails.cache.write "ktio:#{currency.code}:depositTipLink", params[:depositTipLink]
		end
		
		Rails.cache.write "ktio:all:enableCharge", params[:enableCharge]
		Rails.cache.write "ktio:all:enableWithdraw", params[:enableWithdraw]
		Rails.cache.write "ktio:all:depositTip", params[:depositTip]
		Rails.cache.write "ktio:all:depositTipLink", params[:depositTipLink]
		
	else
		currency = Currency.find_by_code(params[:asset].downcase)	
		Rails.cache.write "ktio:#{currency.code}:enableCharge", params[:enableCharge]
		Rails.cache.write "ktio:#{currency.code}:enableWithdraw", params[:enableWithdraw]
		Rails.cache.write "ktio:#{currency.code}:depositTip", params[:depositTip]
		Rails.cache.write "ktio:#{currency.code}:depositTipLink", params[:depositTipLink]
	end
	{"msg": "success"}
end	


desc 'Get trade settings'
params do
	use :auth, :who
end
get "/tradeget" do    
	markets = []
	Market.all.inject({}) do |h, m|
		markets.push(m.unit_info.merge({:warmState => Rails.cache.read("ktio:#{m.id}:warmState"), :warmStateMsg => Rails.cache.read("ktio:#{m.id}:warmStateMsg"), :warmStateMsgLink => Rails.cache.read("ktio:#{m.id}:warmStateMsgLink")}))
	end  
markets.push({:name => 'ALL',  :warmState => Rails.cache.read("ktio:all:warmState"), :warmStateMsg => Rails.cache.read("ktio:all:warmStateMsg"), :warmStateMsgLink => Rails.cache.read("ktio:all:warmStateMsgLink")})
	
	markets
end


desc 'Set trade control for a given currency'
params do
	use :auth, :who
	requires :marketName, type: String  # i can not use :market, because it is with real markets values . Check named_params.rb for :market definition
	requires :warmState, type: String
	requires :warmStateMsg, type: String
	requires :warmStateMsgLink, type: String
end
get "/marketset/:marketName" do
	warmStateMsgLink = params[:warmStateMsgLink]
	#Rails.logger.info "DBG: warmStateMsgLink: #{warmStateMsgLink}"
	if params[:marketName].downcase=='all'
	
		Market.all.inject({}) do |h, m|
			Rails.cache.write "ktio:#{m.base_unit}#{m.quote_unit}:warmState", params[:warmState]
			Rails.cache.write "ktio:#{m.base_unit}#{m.quote_unit}:warmStateMsg", params[:warmStateMsg]
			Rails.cache.write "ktio:#{m.base_unit}#{m.quote_unit}:warmStateMsgLink", warmStateMsgLink
		end
		
		Rails.cache.write "ktio:all:warmState", params[:warmState]
		Rails.cache.write "ktio:all:warmStateMsg", params[:warmStateMsg]
		Rails.cache.write "ktio:all:warmStateMsgLink", params[:warmStateMsgLink]
		
	else
		m = Market.find params[:marketName]
		Rails.cache.write "ktio:#{m.base_unit}#{m.quote_unit}:warmState", params[:warmState]
		Rails.cache.write "ktio:#{m.base_unit}#{m.quote_unit}:warmStateMsg", params[:warmStateMsg]
		Rails.cache.write "ktio:#{m.base_unit}#{m.quote_unit}:warmStateMsgLink", warmStateMsgLink
	end
	{"msg": "success"}
end	





desc 'Set trade control for a given currency'
params do
	use :auth, :who
	requires :marketName, type: String  # i can not use :market, because it is with real markets values . Check named_params.rb for :market definition
	requires :tickSize, type: String
	requires :minTrade, type: String
	requires :minOrderValue, type: String
end
get "/marketsettings/:marketName" do
	m = Market.find params[:marketName]
		Rails.cache.write "ktio:#{m.base_unit}#{m.quote_unit}:tickSize", params[:tickSize]
		Rails.cache.write "ktio:#{m.base_unit}#{m.quote_unit}:minTrade", params[:minTrade]
		Rails.cache.write "ktio:#{m.base_unit}#{m.quote_unit}:minOrderValue", params[:minOrderValue]	
	{"msg": "success"}
end	




	



	end
end