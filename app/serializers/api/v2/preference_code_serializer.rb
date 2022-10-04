module Api
  module V2
    class PreferenceCodeSerializer
      include JSONAPI::Serializer

      set_type :preference_code

      set_id :id

      attributes :description
    end
  end
end
