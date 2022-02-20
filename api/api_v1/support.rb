module APIv1
  class Support < Grape::API
    helpers ::APIv1::NamedParams
    #before { authenticate! }

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
	








	



	end
end