module APIv1
  module Entities
    class Order < Base
      expose :id, as: :orderId, documentation: "Unique order id."
      expose :side, documentation: "Either 'sell' or 'buy'."
      expose :ord_type, as: :orderType, format_with: :capitalize, documentation: "Type of order, either 'limit' or 'market'."
      expose :price, documentation: "Price for each unit. e.g. If you want to sell/buy 1 btc at 3000 EUR, the price is '3000.0'"
  	  expose :last_price
	  expose :last_qty
      expose :avg_price, as: :executedPrice, documentation: "Average execution price, average of price in trades."
      expose :state, documentation: "One of 'wait', 'done', or 'cancel'. An order in 'wait' is an active order, waiting fullfillment; a 'done' order is an order fullfilled; 'cancel' means the order has been cancelled."
	  expose :status
      expose :currency, as: :symbol, format_with: :uppercase, documentation: "The market in which the order is placed, e.g. 'btceur'. All available markets can be found at /api/v1/markets."
      expose :created_at, as: :time, format_with: :timestamp1000, documentation: "Order create time in timestamp format."
      expose :origin_volume, as: :origQty, documentation: "The amount user want to sell/buy. An order could be partially executed, e.g. an order sell 5 btc can be matched with a buy 3 btc order, left 2 btc to be sold; in this case the order's volume would be '5.0', its remaining_volume would be '2.0', its executed volume is '3.0'."
      expose :volume, as: :remaining_volume, documentation: "The remaining volume, see 'volume'."
      expose :ask, as: :baseAsset, format_with: :uppercase
	  expose :bid, as: :quoteAsset, format_with: :uppercase
expose :isStopLimit
expose :isReadyForMatching
expose :stopPrice
expose :stopPriceTrigger
      expose :executed_volume, as: :executedQty, documentation: "The executed volume, see 'volume'." do |order, options|
        order.origin_volume - order.volume
      end
       expose :executedQuoteQty
      expose :trades_count
      expose :trades, if: {type: :full} do |order, options|
        ::APIv1::Entities::Trade.represent order.trades, side: side
      end
      private
      def side
        @side ||= @object.type[-3, 3] == 'Ask' ? 'SELL' : 'BUY'
      end
      def status
        @status = @object.state == 'cancel' ? 'Canceled' : @object.state == 'wait' ? 'Partial Fill' : 'Filled'
      end
       def executedQuoteQty
        @executedQuoteQty = @object.avg_price * (@object.origin_volume - @object.volume)
      end
    end
  end
end