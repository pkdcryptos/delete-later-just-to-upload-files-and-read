module APIv1
  module Entities
    class Withdraw < Base
      expose :id, documentation: "Unique withdraw id."
      expose :currency
      expose :sum, format_with: :decimal
      expose :amount, format_with: :decimal
      expose :fee, as: :transactionFee
      expose :txid
      expose :created_at, format_with: :timestamp
      expose :aasm_state, as: :state
      expose :fund_uid, as: :address
    end
  end
end