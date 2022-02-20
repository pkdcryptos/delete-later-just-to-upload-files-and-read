module APIv1
  module Entities
    class Member < Base
      expose :id
      expose :sn
      expose :email
      expose :activated
      expose :accounts, using: ::APIv1::Entities::Account
    end
  end
end
