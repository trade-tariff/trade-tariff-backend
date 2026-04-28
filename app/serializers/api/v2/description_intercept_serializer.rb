module Api
  module V2
    class DescriptionInterceptSerializer
      include JSONAPI::Serializer

      set_type :description_intercept
      set_id :id

      attributes :term,
                 :sources,
                 :message,
                 :excluded,
                 :created_at,
                 :updated_at,
                 :guidance_level,
                 :guidance_location,
                 :escalate_to_webchat,
                 :filter_prefixes
    end
  end
end
