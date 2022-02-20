module APIv1
  module Entities
    class Fundsource < Base
      expose :id
      expose :member_id, as: :userId
      expose :currency, as: :asset, format_with: :uppercase
      expose :uid, as: :address
      expose :extra, as: :name
      expose :whitelisted, as: :whiteStatus
    end
  end
end
