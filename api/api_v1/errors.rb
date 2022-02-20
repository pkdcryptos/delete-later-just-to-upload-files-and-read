module APIv1
  module ExceptionHandlers
    def self.included(base)
      base.instance_eval do
        rescue_from Grape::Exceptions::ValidationErrors do |e|
          Rack::Response.new({
            error: {
              code: 1001,
              message: e.message
            }
          }.to_json, e.status)
        end
      end
    end
  end
  class Error < Grape::Exceptions::Base
    attr :code, :text
    # code: api error code defined by Ktio, errors originated from
    # subclasses of Error have code start from 2000.
    # text: human readable error message
    # status: http status code
    def initialize(opts={})
      @code    = opts[:code]   || 2000
      @text    = opts[:text]   || ''
      @status  = opts[:status] || 400
      @message = {error: {code: @code, message: @text}}
    end
  end
  class AuthorizationError < Error
    def initialize
      super code: 2001, text: 'Authorization failed', status: 401
    end
  end
  class CreateOrderError < Error
    def initialize(e)
      #super code: 2002, text: "Failed to create order. Reason: #{e}", status: 400
      super code: 2002, text: "Failed to create order", status: 400
    end
  end
  class MinOrderValueError < Error
    def initialize(e)
		super code: 2002, text: "Failed to create order. Reason: Total must be at least #{e}", status: 400
      #super code: 2002, text: "Failed to create order", status: 400
    end
  end
  class TradingSuspendedError < Error
    def initialize()
      super code: 2002, text: "Trading suspended", status: 400
    end
  end
  class CancelOrderSuspendedError < Error
    def initialize()
      super code: 2002, text: "Cancelorder suspended", status: 400
    end
  end
  class CreateMemberError < Error
    def initialize(e)
      #super code: 2002, text: "Rescue Error, Failed to create member. Reason: #{e}", status: 400
      super code: 2002, text: "Failed to create member", status: 400
    end
  end
  class ResendRegisterMailError < Error
    def initialize(e)
      #super code: 2002, text: "Rescue Error, Failed to resendRegisterMail. Reason: #{e}", status: 400
      super code: 2002, text: "Failed to resendRegisterMail", status: 400
    end
  end
  class UpdatePasswordError < Error
    def initialize(e)
      #super code: 2002, text: "Rescue Error, Failed to updatePassword. Reason: #{e}", status: 400
      super code: 2002, text: "Failed to updatePassword", status: 400
    end
  end
  class ForgotPasswordError < Error
    def initialize(e)
      #super code: 2002, text: "Rescue Error, Failed to forgotPassword. Reason: #{e}", status: 400
      super code: 2002, text: "Failed to forgotPassword", status: 400
    end
  end
  class ResetPasswordError < Error
    def initialize(e)
      #super code: 2002, text: "Rescue Error, Failed to resetPassword. Reason: #{e}", status: 400
      super code: 2002, text: "Failed to resetPassword", status: 400
    end
  end
  class MemberLoginError < Error
    def initialize(e)
      #super code: 2002, text: "Rescue Error, Failed to login member. Reason: #{e}", status: 400
      super code: 2002, text: "Failed to login member", status: 400
    end
  end
 class CreateAddressError < Error
    def initialize(e)
      super code: 2002, text: "Rescue Error, Failed to create address. Reason: #{e}", status: 400
      #super code: 2002, text: "Failed to create address", status: 400
    end
  end
  class GeneralError < Error
    def initialize(e)
      super code: 2002, text: "Rescue Error Reason: #{e}", status: 400
      #super code: 2002, text: "Failed to execute code", status: 400
    end
  end
  class CoinTransferError < Error
    def initialize(e)
      super code: 2003, text: "Failed to cancel order. Reason: #{e}", status: 400
      #super code: 2003, text: "Failed, probably insufficient coins in the wallet", status: 400
    end
  end
   class CancelOrderError < Error
    def initialize(e)
      #super code: 2003, text: "Failed to cancel order. Reason: #{e}", status: 400
      super code: 2003, text: "Failed to cancel order", status: 400
    end
  end
  class OrderNotFoundError < Error
    def initialize(id)
      super code: 2004, text: "Order##{id} doesn't exist.", status: 404
      #super code: 2004, text: "Fail", status: 404
    end
  end
   class OrdersNotFoundError < Error
    def initialize
      super code: 2004, text: "Orders not found", status: 404
      #super code: 2004, text: "Fail", status: 404
    end
  end
  class IncorrectSignatureError < Error
    def initialize(signature)
      #super code: 2005, text: "Signature #{signature} is incorrect.", status: 401
      super code: 2005, text: "Signature is incorrect.", status: 401
    end
  end
  class TonceUsedError < Error
    def initialize(access_key, tonce)
      #super code: 2006, text: "The tonce #{tonce} has already been used by access key.", status: 401
      super code: 2006, text: "The tonce has already been used by access key.", status: 401
    end
  end
  class InvalidTonceError < Error
    def initialize(tonce, now)
      #super code: 2007, text: "The tonce #{tonce} is invalid, current timestamp is #{now}.", status: 401
      super code: 2007, text: "The tonce is invalid, current timestamp is #{now}.", status: 401
    end
  end
  class InvalidAccessKeyBPIError < Error
    def initialize()
      #super code: 2008, text: "BPI: The access key does not exist.", status: 401
      super code: 2008, text: "Access key does not exist.", status: 401
    end
  end
  class DisabledAccessKeyBPIError < Error
    def initialize()
      #super code: 2009, text: "BPI: The access key is disabled.", status: 401
      super code: 2009, text: "Access key is disabled.", status: 401
    end
  end
  class ExpiredAccessKeyBPIError < Error
    def initialize()
      #super code: 2010, text: "BPI: The access key has expired.", status: 401
      super code: 2010, text: "Access key has expired.", status: 401
    end
  end
  class OutOfScopeBPIError < Error
    def initialize
      #super code: 2011, text: "BPI: Requested API is out of access key scopes.", status: 401
      super code: 2011, text: "Requested API is out of access key scopes.", status: 401
    end
  end
  class InvalidAccessKeyError < Error
    def initialize()
      #super code: 2008, text: "The access key does not exist.", status: 401
      super code: 2008, text: "The access key does not exist.", status: 401
    end
  end
  class DisabledAccessKeyError < Error
    def initialize()
      #super code: 2009, text: "The access key is disabled.", status: 401
      super code: 2009, text: "The access key is disabled.", status: 401
    end
  end
  class ForceLogOutError < Error
    def initialize()
      #super code: 9999, text: "Force logout", status: 401
      super code: 9999, text: "Account restrricted", status: 401
    end
  end
  class ForceLogOutBPIError < Error
    def initialize()
      #super code: 9999, text: "Force logout", status: 401
      super code: 9999, text: "Account restricted", status: 401
    end
  end
  class ExpiredAccessKeyError < Error
    def initialize()
      #super code: 2010, text: "The access key has expired.", status: 401
      super code: 2010, text: "The access key has expired.", status: 401
    end
  end
  class OutOfScopeError < Error
    def initialize
      #super code: 2011, text: "Requested API is out of access key scopes.", status: 401
      super code: 2011, text: "Requested API is out of access key scopes.", status: 401
    end
  end
  class DepositByTxidNotFoundError < Error
    def initialize(txid)
      #super code: 2012, text: "Deposit##txid=#{txid} doesn't exist.", status: 404
      super code: 2012, text: "Deposit doesn't exist.", status: 404
    end
  end
end