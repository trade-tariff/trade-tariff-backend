module Api
  module V2
    class PreferenceCodeSerializer
      include JSONAPI::Serializer

      set_type :preference_code

      attributes :code, :description
    end
  end
end
