module APIv1
  module Entities
    class Usertradeorderdetail < Base
      expose :totalEntity, with: APIv1::Entities::Total
      expose :usertradeorderdetailEntity, with: APIv1::Entities::Trade
    end
  end
end