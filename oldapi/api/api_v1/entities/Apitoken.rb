module APIv1
  module Entities
    class Apitoken < Base
      expose :id
      expose :member_id, as: :userId
      expose :access_key, as: :apiKey
      expose :label, as: :apiName
      expose :tradeIp
      expose :withdrawIp
      expose :ruleId
      expose :withdraw
      expose :apiEmailVerify
      expose :status
      expose :secretKey
      private
       def status
        if @object.trusted_ip_list.blank?
        @status = 1
        else
        @status = 2
        end
      end
      def secretKey
        @secretKey = "--"        
      end
      def tradeIp
        if @object.trusted_ip_list.blank?
        @tradeIp = '0.0.0.0'
        else
        @tradeIp = @object.trusted_ip_list
        end
      end
      def withdrawIp
        if @object.trusted_ip_list.blank?
        @withdrawIp = '0.0.0.0'
        else
        @withdrawIp = @object.trusted_ip_list
        end
      end
    end
  end
end