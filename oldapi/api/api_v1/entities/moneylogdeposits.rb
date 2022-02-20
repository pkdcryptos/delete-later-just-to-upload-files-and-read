module APIv1
  module Entities
    class Moneylogdeposits < Base
      expose :totalEntity, with: APIv1::Entities::Total
      expose :depositsEntity, with: APIv1::Entities::Deposit
    end
  end
end