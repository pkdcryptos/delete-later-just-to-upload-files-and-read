module APIv1
  module Entities
    class Qtrade < Base
      expose :id, as: :tid
      expose :price
      expose :volume, as: :qty
      expose :created_at, as: :date, format_with: :timestamp
      expose :type
      expose :tradetime, as: :time
      private
       def type
        if @object.trend=='down'
        @type = 'sell'
        else
        @type = 'buy'
        end
      end
    end
  end
end