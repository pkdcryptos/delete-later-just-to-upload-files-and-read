module Withdraws
  module Coinable
    extend ActiveSupport::Concern

    def set_fee
      self.fee = self.channel.fee
    end

    

    def audit!
#       result = CoinRPC[currency].validateaddress(fund_uid)

#       if result.nil? || (result[:isvalid] == false)
#         #Rails.logger.info "DBG: #{self.class.name}##{id} uses invalid address: #{fund_uid.inspect}"
#         reject
#         save!
#       elsif (result[:ismine] == true) || PaymentAddress.find_by_address(fund_uid)
#         #Rails.logger.info "DBG: #{self.class.name}##{id} uses hot wallet address: #{fund_uid.inspect}"
#         reject
#         save!
#       else
        super
      #end
    end

    def as_json(options={})
      super(options).merge({})
    end

  end
end

