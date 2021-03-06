module APIv1
  module Entities
    class OrderBook < Base
      expose :asks, using: Order
      expose :bids, using: Order
    end
  end
end
