module APIv1
  module Entities
    class Market < Base
      expose :id, documentation: "Unique market id. It's always in the form of xxxyyy, where xxx is the base currency code, yyy is the quote currency code, e.g. 'btceur'. All available markets can be found at /api/v1/markets."
      expose :name
      expose :base_unit
    end
  end
end