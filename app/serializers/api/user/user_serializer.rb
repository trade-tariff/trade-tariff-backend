module Api
  module User
    class UserSerializer
      include JSONAPI::Serializer

      set_type :user

      set_id :external_id

      attributes :external_id, :email
    end
  end
end
