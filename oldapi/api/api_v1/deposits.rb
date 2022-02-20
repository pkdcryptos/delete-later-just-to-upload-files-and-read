require_relative 'validations'
module APIv1
  class Deposits < Grape::API
    helpers ::APIv1::NamedParams
	
    before { authenticate! }
	
desc 'Get your deposits history.'
params do
	use :auth
	optional :currency, type: String, values: Currency.all.map(&:code), desc: "Currency value contains  #{Currency.all.map(&:code).join(',')}"
	optional :limit, type: Integer, range: 1..100, default: 3, desc: "Set result limit."
	optional :state, type: String, values: Deposit::STATES.map(&:to_s)
end
desc 'Get your deposits history.'
params do
	use :auth, :who
	optional :rows, type: Integer, range: 1..100, default: 3, desc: "Set result limit."
	optional :page,  type: Integer, default: 1, desc: "Specify the page of paginated results."
end
post "/mydeposits" do
	totalValue = current_user.deposits.limit(100).recent.size
	totalCollection = [{ "total":  totalValue }]
	deposits = current_user.deposits.limit(100).recent
		.page(params[:page])
		.per(params[:rows])
	present [
	"totalEntity": totalCollection, "depositsEntity": deposits
	], with: APIv1::Entities::Moneylogdeposits 
end


desc 'Get your withdraws history.'
params do
	use :auth, :who
	optional :rows, type: Integer, range: 1..100, default: 3, desc: "Set result limit."
	optional :page,  type: Integer, default: 1, desc: "Specify the page of paginated results."
end
post "/mywithdraws" do
	totalValue = current_user.withdraws.limit(100).recent.size
	totalCollection = [{ "total":  totalValue }]
	withdraws = current_user.withdraws.limit(100).recent
		.page(params[:page])
		.per(params[:rows])
	present [
	"totalEntity": totalCollection, "withdrawsEntity": withdraws
	], with: APIv1::Entities::Moneylogwithdraws
end
	
	
  end
end