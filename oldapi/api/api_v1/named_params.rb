module APIv1
  module NamedParams
    extend ::Grape::API::Helpers
    params :auth do
      optional :access_key, type: String,  desc: "Access key."
      optional :tonce,      type: Integer, desc: "Tonce is an integer represents the milliseconds elapsed since Unix epoch."
      optional :signature,  type: String,  desc: "The signature of your request payload, generated using your secret key."
    end
	params :who do
      optional :who,  type: String,  desc: "The role of api initiator"
    end
    params :market do
      requires :market, type: String, values: ::Market.all.map(&:id), desc: ::APIv1::Entities::Market.documentation[:id]
    end
    params :asset do
      requires :asset, type: String, desc: "baseasset"
    end
    params :address do
      requires :id, type: Integer,  desc: "member id"
      requires :currency, type: String,  desc: "currency to create new address or get assigned address"
    end
    params :token do
      requires :token, type: String, desc: "Activation token"
    end
    params :order do
      requires :side,   type: String, values: %w(sell buy), desc: ::APIv1::Entities::Order.documentation[:side]
      requires :volume, type: String, desc: ::APIv1::Entities::Order.documentation[:volume]
      optional :price,  type: String, desc: ::APIv1::Entities::Order.documentation[:price]
      optional :stopPrice,  type: String
      optional :stopPriceTrigger,  type: String
      requires :ord_type, type: String, values: %w(limit market stoplimit), desc: ::APIv1::Entities::Order.documentation[:type]
    end
    params :signup do
      requires :email,   type: String, desc: "Email to register"
      requires :password, type: String, desc: "Password to register"
    end
    params :updatepassword do
      requires :email,   type: String, desc: "Email"
      requires :oldPwd, type: String, desc: "Old password"
      requires :newPwd, type: String, desc: "New password"
    end
    params :resetpassword do
      requires :email,   type: String, desc: "Email"
      requires :vc, type: String, desc: "vc"
      requires :newPassword, type: String, desc: "New password"
    end
    params :email do
      requires :email,   type: String, desc: "Email to register"
    end
    params :order_id do
      requires :id, type: Integer, desc: ::APIv1::Entities::Order.documentation[:id]
    end
    params :trade_filters do
      optional :limit,     type: Integer, range: 1..1000, default: 50, desc: 'Limit the number of returned trades. Default to 50.'
      optional :timestamp, type: Integer, desc: "An integer represents the seconds elapsed since Unix epoch. If set, only trades executed before the time will be returned."
      optional :from,      type: Integer, desc: "Trade id. If set, only trades created after the trade will be returned."
      optional :to,        type: Integer, desc: "Trade id. If set, only trades created before the trade will be returned."
      optional :order_by,     type: String, values: %w(asc desc), default: 'desc', desc: "If set, returned trades will be sorted in specific order, default to 'desc'."
    end
  end
end