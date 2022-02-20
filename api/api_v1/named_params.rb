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
    
    
  end
end