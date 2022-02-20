module APIv1
  module Entities
    class Usertrades < Base
      expose :totalEntity, with: APIv1::Entities::Total
      expose :usertradesEntity, with: APIv1::Entities::Trade
    end
  end
end