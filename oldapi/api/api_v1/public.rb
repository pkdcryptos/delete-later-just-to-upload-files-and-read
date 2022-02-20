module APIv1
  class Public < Grape::API
    helpers ::APIv1::NamedParams
	
	
	desc 'Post withdraw complete'
    params do
      requires :seckey, type: String,  desc: "withdraw key"
      requires :id, type: Integer
      requires :txid, type: String      
    end
    post "/withdrawcomplete" do
	begin
    if params[:seckey]=='abcd'
	    Withdraw.transaction do
			withdraw = Withdraw.find(params[:id]).lock!
			if withdraw
					withdraw.whodunnit('Worker::WithdrawCoin') do
						  withdraw.update_attributes(:node_status => 'done', :txid => params[:txid], :aasm_state => 'done')
						  if withdraw.save!
						  {"success": true, "msg": "updated"}
						  else
						  {"success": false, "msg": "Unable to update withdraw table field node_status"}
						  end
					end
			else
			{"success": false, "msg": "no entries"}
			end
		end 
    else
    {"success": false, "msg": "key error"}
    end
	rescue
	Rails.logger.debug $!.backtrace.join("\n")
	raise GeneralError, $!
	end 
end

desc 'Withdraw control disable'
params do
  requires :seckey, type: String,  desc: "withdraw key"
  requires :id, type: Integer
end
post "/withdrawcontroldisable" do
	if params[:seckey]=='abcd'
		withdrawcontrol = Withdrawcontrol.where('id = ?',params[:id]).first
		 withdrawcontrol.update_column :enabled, 0
		 withdrawcontrol.save!
		 {"success": true}
	else
	{"success": false, "msg": "error"}
	end
end

     desc 'Get next withdraw address'
    params do
      requires :seckey, type: String,  desc: "withdraw key"
      
    end
    post "/getnextwithdraw" do
	begin
	Rails.logger.info "DBG: getnextwithdraw called at #{Time.now} "
    if params[:seckey]=='abcd'
	    withdraw = Withdraw.where(currency: Withdrawcontrol.select("id").where(enabled: 1)).joins(:member).where("members.withdrawDisabled" => 0, "members.accessCode" => 2, "members.g2fa_verified" => 1).where(aasm_state: 'processing').where(validated: 1).where(node_status: '').first 
		 
		 #aasm_state: processing DONE
		 #validated: 1 DONE
		 #node_status:'' DONE
		 #2fa: g2fa_verified=1 DONE
		 #member: withdrawDisabled=0 DONE
		 #member: accessCode=2 DONE
		 #withdrawstate: enabled for coin and not in kill state
		 
		 @withdrawkills = Withdrawkill.where('id > ?',0).first
		 withdrawkilled = @withdrawkills.killed
		
		 
		 
		 if withdrawkilled==true
		 {"success": false, "killed": 1, "msg": "killed"}
		 else
		 
				 if withdraw
						withdraw.whodunnit('Worker::WithdrawCoin') do
							  withdraw.update_column :node_status, 'working'
							  if withdraw.save!
							  Rails.logger.info "DBG: getnextwithdraw returning with #{withdraw.id} "
							  present withdraw, with: APIv1::Entities::Withdraw
							  else
							  {"success": false, "msg": "Unable to update withdraw table field node_status"}
							  end
						end
				else
				{"success": false, "msg": "no entries"}
				end
		 
		 end
		 
	   
    else
    {"success": false, "msg": "key error"}
    end
   
rescue
	Rails.logger.debug $!.backtrace.join("\n")
	raise GeneralError, $!
	end 
    end
	
desc 'Get OHLC(k line) of specific market. - to support interval'
params do
  use :market
  optional :limit,     type: Integer, default: 500, values: 1..1000, desc: "Limit the number of returned data points, default to 500."
  optional :interval,    type: String,  default: '1m', values: %w(1m 3m 5m 15m 30m 1h 2h 4h 6h 12h 1d 3d 1w), desc: "Time period of K line, default to 1m. You can choose between 1m 3m 5m 15m 30m 1h 2h 4h 6h 12h 1d 3d 1w"
  optional :sts, type: Integer, desc: "An integer represents the seconds elapsed since Unix epoch. If set, only k-line data after that time will be returned."
end
get "/k1" do
  get_k1_json
end


desc 'Get usdt pricing.'
get "/btcusdt" do
  key = "ktio:btcusdt"      
  Rails.cache.read(key) 
end

desc 'Get usdt pricing.'
get "/ethusdt" do
  key = "ktio:ethusdt"      
  Rails.cache.read(key) 
end

desc 'Get usdt pricing.'
get "/p2pusdt" do
  key = "ktio:p2pusdt"      
  Rails.cache.read(key) 
end

desc 'Get usdt pricing.'
get "/trxusdt" do
  key = "ktio:trxusdt"      
  Rails.cache.read(key) 
end


desc 'Get all rates'
get "/getRates" do
  {"btcusdt":Rails.cache.read("ktio:btcusdt"), "ethusdt":Rails.cache.read("ktio:ethusdt"), "trxusdt":Rails.cache.read("ktio:trxusdt"), "p2pusdt":Rails.cache.read("ktio:p2pusdt"), "BTC":Rails.cache.read("ktio:btcusdt"), "ETH":Rails.cache.read("ktio:ethusdt"), "P2P":Rails.cache.read("ktio:p2pusdt"), "TRX":Rails.cache.read("ktio:trxusdt"), "exchangerates": Rails.cache.read("ktio:exchangerates")}
end


desc 'Get usdt pricing.'
get "/cnyusd" do
  key = "ktio:cnyusd"      
  Rails.cache.read(key) 
end

desc 'Get all available markets.'
get "/markets" do
	present Market.all, with: APIv1::Entities::Market
end

desc 'Get ticker of all markets.'
get "/tickers" do
  Market.all.inject({}) do |h, m|
	h[m.id] = format_ticker Global[m.id].ticker
	h
  end
end


desc 'Get products.'
get "/products" do    
	pmarket = []	    
	allWarmState=Rails.cache.read("ktio:all:warmState")
	if allWarmState=='0' or allWarmState=='1' 
		allWarmStateMsg=Rails.cache.read("ktio:all:warmStateMsg")
		allWarmStateMsgLink=Rails.cache.read("ktio:all:warmStateMsgLink")
		Market.all.inject({}) do |h, m|
		pmarket.push(m.unit_info.merge(Global[m.id].ticker).merge({:warmState => allWarmState, :warmStateMsg => allWarmStateMsg, :warmStateMsgLink => allWarmStateMsgLink, "type":"trade"}))
		end    
	else
		Market.all.inject({}) do |h, m|
		warmState=Rails.cache.read("ktio:#{m.id}:warmState")
		warmStateMsg=Rails.cache.read("ktio:#{m.id}:warmStateMsg")
		warmStateMsgLink=Rails.cache.read("ktio:#{m.id}:warmStateMsgLink")
		pmarket.push(m.unit_info.merge(Global[m.id].ticker).merge({:warmState => warmState, :warmStateMsg => warmStateMsg, :warmStateMsgLink => warmStateMsgLink, "type":"trade"}))
		end    
	end     
	# pmarket.push({"symbol":"BTCUSDT", "type":"rate", "baseAsset":"BTC", "quoteAsset":"USDT", "close":Rails.cache.read('ktio:btcusdt')})
	# pmarket.push({"symbol":"ETHUSDT", "type":"rate", "baseAsset":"ETH", "quoteAsset":"USDT", "close":Rails.cache.read('ktio:ethusdt')})
	# pmarket.push({"symbol":"P2PUSDT", "type":"rate", "baseAsset":"P2P", "quoteAsset":"USDT", "close":Rails.cache.read('ktio:p2pusdt')})
	# pmarket.push({"symbol":"TRXUSDT", "type":"rate", "baseAsset":"TRX", "quoteAsset":"USDT", "close":Rails.cache.read('ktio:trxusdt')})
	{"data": pmarket}
	
end


desc 'Get product'
params do
  use :market
end
get "/products/:market" do
pmarket = []
allWarmState=Rails.cache.read("ktio:all:warmState")
	if allWarmState=='0' or allWarmState=='1' 
		allWarmStateMsg=Rails.cache.read("ktio:all:warmStateMsg")
		allWarmStateMsgLink=Rails.cache.read("ktio:all:warmStateMsgLink")
		Market.all.inject({}) do |h, m|
		if m.id == params[:market].downcase
		pmarket.push(m.unit_info.merge(Global[m.id].ticker).merge({:warmState => allWarmState, :warmStateMsg => allWarmStateMsg, :warmStateMsgLink => allWarmStateMsgLink}))
		end
		end    
	else
		Market.all.inject({}) do |h, m|
		if m.id == params[:market].downcase
		warmState=Rails.cache.read("ktio:#{m.id}:warmState")
		warmStateMsg=Rails.cache.read("ktio:#{m.id}:warmStateMsg")
		warmStateMsgLink=Rails.cache.read("ktio:#{m.id}:warmStateMsgLink")
		pmarket.push(m.unit_info.merge(Global[m.id].ticker).merge({:warmState => warmState, :warmStateMsg => warmStateMsg, :warmStateMsgLink => warmStateMsgLink}))
		end
		end    
	end 
{"data": pmarket}        
end

desc 'Get activities'
get "/activity" do 
	@activities = Activity.where(active: 1)   
	{"success":true, "data": @activities}
end

desc 'Get notices'
get "/notice" do 
	@notices = Notice.where(active: 1)   
	{"success":true, "data": @notices}
end

desc 'Get recommends'
get "/recommend" do 
	@recommends = Recommend.where(active: 1)   
	@recommends
end
	
	
desc 'Get userasset.'
get "/assets" do    
	assets = []
	Currency.all.each do |currency|
		assets.push(currency.userasset_info)
	end    
	assets   
end

desc 'Get assetpic.'
get "/getassetpic" do    
	assets = []
	Currency.all.each do |currency|
		assets.push(currency.getassetpic_info)
	end    
	{"data":assets}   
end

desc 'Get allasset.'
get "/getallasset" do    
	assets = []
	Currency.all.each do |currency|
		assets.push(currency.getallasset_info)
	end    
	assets   
end

desc 'Get symbol by asset'
params do
  use :asset
end
get "/getsymbolbyasset/:asset" do
	symbols = []
	Market.all.each do |m|
		if m.baseAsset == params[:asset]
		symbols.push(m.getsymbol_info) 
		end
	end 
	{"success":true,"symbols":symbols }     
end


desc 'Get asset'
params do
  use :asset
end
get "/getasset/:asset" do
	asset = Currency.find_by_code(params[:asset].downcase)
	asset.getasset_info   
end

desc 'Get server current time, in seconds since Unix epoch.'
get "/timestamp" do
	::Time.now.to_i
end


desc 'Signup'
params do
	use :signup
end
post "/signup" do
begin
ActiveRecord::Base.transaction do
	email = params[:email].to_s.strip.downcase
	password = params[:password]
	password2 = params[:password2] 
	user_type = params[:user_type] 
	referredBy = params[:referredBy].to_s.strip  
	nickname = params[:nickname].to_s.strip.downcase.camelize
	#nickname shd niot have underscores
	nickname = nickname.gsub('_', '')
	Rails.logger.info "DBG: form data  #{email}  #{password}  #{password2}  [#{referredBy}]  [#{nickname}]  "
	Rails.logger.info "DBG: signup  email #{email}  password #{password}   password2 #{password2}  "
	
	if email.blank? or nickname.blank? or password.blank? or password2.blank? and password!=password2  
		msg = {"success": 0, "msg": "Empty fields"}
	else   
		memberByEmail = Member.find_by_email email
		memberExists = 0
		Rails.logger.info "DBG: memberByEmail #{memberByEmail.inspect}  "
		if referredBy.blank?
		else
			memberByreferralId = Member.find_by_referralId referredBy
			Rails.logger.info "DBG: memberByreferralId #{memberByreferralId.inspect}  "
			if memberByreferralId
			else
				memberExists = 1
				msg = {"success": 0, "msg": "ReferralId does not exist"}
			end
		end
		if memberByEmail
			memberExists = 1
			msg = {"success": 0, "msg": "Email exists already"}
		end
		# memberByNickname = Member.find_by_nickname nickname
		# Rails.logger.info "DBG: memberByNickname #{memberByNickname.inspect}  "
		# if memberByNickname 
			# memberExists = 1
			# msg = {"success": 0, "msg": "Nickname exists already"}
		# end
		if memberExists == 1
			msg
		else
			auth_hash={'provider' => 'identity','info' => { 'email' => email }}
			# below  identity create helps to login in both ktio and our site. Once commented, ktio website can not be logged in. For now keep it open for testing
			identity = Identity.create(email: email, password: password, password_confirmation: password2, is_active: false)
			Rails.logger.info "DBG: Identity created identity: #{identity.inspect}"
			member = Member.create(email: email, nickname: nickname, user_type: user_type, activated: false)
			Rails.logger.info "DBG: 1"
			activation_code=SecureRandom.urlsafe_base64(30).tr('_-', 'xx')
			Rails.logger.info "DBG: 2"
			forbidAccountToken=SecureRandom.urlsafe_base64(30).tr('_-', 'xx')
			Rails.logger.info "DBG: 3"
			password = Digest::SHA256.hexdigest(password)
			Rails.logger.info "DBG: 4"
			referralId = SecureRandom.urlsafe_base64(5).tr('_-', 'xx') + '_' + member.id.to_s
			nickname = 'U' + member.id.to_s
			member.update_attributes(:sn => member.id, :password => password, :nickname => nickname, :referralId => referralId, :referredBy => referredBy, :activation_code => activation_code, :forbidAccountToken => forbidAccountToken, :reset_password_code => "", :reset_password_date => Time.now)
			member.save
			bpitoken = member.build_bpitoken(label: 'L1', trusted_ip_list: '127.0.0.1', scopes: 'all')
			bpitoken.save
			
			
			
			msg = {"success": 1, "userId": member.id, "nickname": nickname, "email": member.email, "msg": "User account created successfully"}
		end    
	end 
	
end

rescue
	Rails.logger.info "DBG: Failed to create member: #{$!}"
	Rails.logger.debug member.inspect
	Rails.logger.debug $!.backtrace.join("\n")
	raise CreateMemberError, $!
end
end

	
desc 'Resend Registermail'
params do
	use :email
end
post "/resendRegisterMail" do
begin
ActiveRecord::Base.transaction do
	email = params[:email]
	if email    
		member = Member.find_by_email email
		#Rails.logger.info "DBG: member find by email #{member.activated}  #{member.inspect}"
		if member.activated
			msg = {"success": 0, "userId": member.id,  "msg": "Account already activated"}
		else
			activation_code=SecureRandom.urlsafe_base64(30).tr('_-', 'xx')
			member.update_attributes(:activation_code => activation_code, :reset_password_code => "", :reset_password_date => Time.now)
			member.save
			msg = {"success": 1, "userId": member.id, "activation_code": activation_code,  "msg": "Success"}
		end
	else 
		msg = {"success": 0, "msg": "Invalid fields"}
	end   
end
rescue
	#Rails.logger.info "DBG:Failed to resendRegisterMail: #{$!}"
	Rails.logger.debug $!.backtrace.join("\n")
	raise ResendRegisterMailError, $!
end
end

desc 'reset phone'
params do
	use :email
end
post "/resetPhone" do
begin
ActiveRecord::Base.transaction do
	email = params[:email]
	member = Member.find_by_email email
	reset_phone_code = SecureRandom.urlsafe_base64(30).tr('_-', 'xx')
	member.update_attributes(:reset_phone_code => reset_phone_code, :reset_phone_date => Time.now)
	member.save
	msg = {"success": 1, "userId": member.id, "email": member.email, "vc":reset_phone_code,  "msg": "Success"}
end
rescue
	#Rails.logger.info "DBG: Failed to forgotPassword: #{$!}"
	Rails.logger.debug $!.backtrace.join("\n")
	raise ForgotPasswordError, $!
end
end

desc 'forgot password'
params do
	use :email
end
post "/forgotPassword" do
begin
ActiveRecord::Base.transaction do
	email = params[:email]
	member = Member.find_by_email email
	reset_password_code = SecureRandom.urlsafe_base64(30).tr('_-', 'xx')
	member.update_attributes(:reset_password_code => reset_password_code, :reset_password_date => Time.now)
	member.save
	msg = {"success": 1, "userId": member.id, "email": member.email, "vc":reset_password_code,  "msg": "Success"}
end
rescue
	#Rails.logger.info "DBG: Failed to forgotPassword: #{$!}"
	Rails.logger.debug $!.backtrace.join("\n")
	raise ForgotPasswordError, $!
end
end

desc 'Reset password'
params do
	use :resetpassword
end
post "/resetPassword" do
begin
ActiveRecord::Base.transaction do
	email = params[:email]
	vc = params[:vc]
	# todo need to check vc
	newPassword = params[:newPassword]
	member = Member.find_by_email email
	if member.reset_password_code==vc
		reset_password_code = SecureRandom.urlsafe_base64(30).tr('_-', 'xx')
		password = Digest::SHA256.hexdigest(newPassword)
		member.update_attributes(:password => password, :reset_password_code => reset_password_code)
		member.save
		msg = {"success": 1, "userId": member.id,  "msg": "Success"}
	else
		msg = {"success": 0, "userId": member.id,  "msg": "Invalid link"}
	end
end
rescue
	#Rails.logger.info "DBG: Failed to resetPassword: #{$!}"
	Rails.logger.debug member.inspect
	Rails.logger.debug $!.backtrace.join("\n")
	raise ResetPasswordError, $!
end
end



desc 'Get recent trades on market, each trade is included only once. Trades are sorted in reverse creation order.'
params do
  use :market, :trade_filters
end
get "/qtrades" do
  #qtrades = Traade.filter(params[:market], time_to, params[:from], params[:to], params[:limit], order_param)
  output = Rails.cache.read("ktio:#{params[:market]}:trades") || []
  #present qtrades, with: APIv1::Entities::Qtrade
  present output
end




end
end