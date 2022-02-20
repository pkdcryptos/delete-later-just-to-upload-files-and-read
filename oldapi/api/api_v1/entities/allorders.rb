module APIv1
  module Entities
    class Allorders < Base
      expose :totalEntity, with: APIv1::Entities::Total
      expose :allordersEntity, with: APIv1::Entities::Order
    end
  end
end