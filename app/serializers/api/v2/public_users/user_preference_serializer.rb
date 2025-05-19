module Api
  module V2
    module PublicUsers
      class UserPreferenceSerializer
        include JSONAPI::Serializer

        set_type :user_preference

        set_id :id

        attributes :user_id,
                   :chapter_ids
      end
    end
  end
end
