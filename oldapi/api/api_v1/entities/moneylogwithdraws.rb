module APIv1
  module Entities
    class Moneylogwithdraws < Base
      expose :totalEntity, with: APIv1::Entities::Total
      expose :withdrawsEntity, with: APIv1::Entities::Withdraw
    end
  end
end