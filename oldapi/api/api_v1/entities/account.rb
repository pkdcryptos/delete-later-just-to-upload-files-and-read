module APIv1
  module Entities
    class Account < Base
      expose :currency, as: :code
      expose :balance, as: :free, format_with: :decimal
      expose :locked,  format_with: :decimal
    end
  end
end