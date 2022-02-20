module APIv1
  module Entities
    class Ptrade < Base
      expose :id, as: :tid
      expose :price
      expose :volume, as: :amount
      expose :funds
      expose :currency, as: :market
      expose :created_at, as: :date
      expose :trend, as: :type
      expose :side do |trade, options|
        options[:side] || trade.side
      end
      expose :order_id, if: ->(trade, options){ options[:current_user] } do |trade, options|
        if trade.ask_member_id == options[:current_user].id
          trade.ask_id
        elsif trade.bid_member_id == options[:current_user].id
          trade.bid_id
        else
          nil
        end
      end
    end
  end
end