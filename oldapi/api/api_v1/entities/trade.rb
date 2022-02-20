module APIv1
  module Entities
    class Trade < Base
      expose :id
      expose :price
      expose :volume, as: :qty
      expose :funds
      expose :currency, as: :market
      expose :created_at, as: :time, format_with: :timestamp1000
      expose :baseAsset, format_with: :uppercase
      expose :quoteAsset, format_with: :uppercase
      expose :ask_fee
      expose :bid_fee
      expose :ask_member_id
      expose :bid_member_id
      expose :side  do |trade, options|
        side = options[:side] || trade.side
        side = side == 'ask' ? 'SELL' : 'BUY'
        side
      end
      expose :orderId, if: ->(trade, options){ options[:current_user] } do |trade, options|
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