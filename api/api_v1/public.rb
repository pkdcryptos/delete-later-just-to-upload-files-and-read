module APIv1
  class Public < Grape::API
    helpers ::APIv1::NamedParams
	##########################################	
		
		
desc 'Ping Ponng'
get "/ping1" do
  msg = {"success": 1, "msg": "PONG1"}
	msg
end


desc 'Get userasset.'
get "/assets" do    
	assets = []
	Currency.all.each do |currency|
		assets.push(currency.userasset_info)
	end    
	assets   
end

desc 'Get server current time, in seconds since Unix epoch.'
get "/timestamp" do
	Rails.logger.info "DBG: ::Time.now.to_i  #{::Time.now.to_i}   "
	::Time.now.to_i
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

desc 'Get usdt pricing.'
get "/cnyusd" do
  key = "ktio:cnyusd"      
  Rails.cache.read(key) 
end



desc 'Get all rates'
get "/getRates" do
  {"btcusdt":Rails.cache.read("ktio:btcusdt"), "ethusdt":Rails.cache.read("ktio:ethusdt"), "trxusdt":Rails.cache.read("ktio:trxusdt"),  "BTC":Rails.cache.read("ktio:btcusdt"), "ETH":Rails.cache.read("ktio:ethusdt"),  "TRX":Rails.cache.read("ktio:trxusdt"), "exchangerates": Rails.cache.read("ktio:exchangerates")}
end

	

desc 'Get allasset.'
get "/getallasset" do    
	assets = []
	Currency.all.each do |currency|
		assets.push(currency.getallasset_info)
	end    
	assets   
end

desc 'Get asset'
params do
  use :asset
end
get "/getasset/:asset" do
	asset = Currency.find_by_code(params[:asset].downcase)
	asset.getasset_info   
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
	user_type = params[:user_type] 
	nickname = params[:nickname].to_s.strip.downcase.camelize
	#nickname shd niot have underscores
	nickname = nickname.gsub('_', '')
	Rails.logger.info "DBG: form data  #{email}  #{password}    [#{nickname}]  "
	Rails.logger.info "DBG: signup  email #{email}  password #{password}    "
	
	if email.blank? or nickname.blank? or password.blank?  
		msg = {"success": 0, "msg": "Empty fields"}
	else   
		memberByEmail = Member.find_by_email email
		memberExists = 0
		Rails.logger.info "DBG: memberByEmail #{memberByEmail.inspect}  "
		
		if memberByEmail
			memberExists = 1
			msg = {"success": 0, "msg": "Email exists already"}
		end
		if memberExists == 1
			msg
		else
			member = Member.create(email: email, nickname: nickname, user_type: user_type, activated: false)
			Rails.logger.info "DBG: 1"
			activation_code=SecureRandom.urlsafe_base64(30).tr('_-', 'xx')
			Rails.logger.info "DBG: 2"
			forbidAccountToken=SecureRandom.urlsafe_base64(30).tr('_-', 'xx')
			Rails.logger.info "DBG: 3"
			password = Digest::SHA256.hexdigest(password)
			Rails.logger.info "DBG: 4"
			nickname = 'U' + member.id.to_s
			member.update_attributes(:sn => member.id, :password => password, :activated => 1, :nickname => nickname, :activation_code => activation_code, :reset_password_code => "", :reset_password_date => Time.now)
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

		
	##########################################		
end
end