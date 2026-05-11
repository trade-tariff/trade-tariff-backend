module Api
  module Admin
    class DescriptionInterceptSerializer
      include JSONAPI::Serializer

      set_type :description_intercept

      attributes :term,
                 :aliases,
                 :sources,
                 :message,
                 :message_header,
                 :excluded,
                 :created_at,
                 :guidance_level,
                 :guidance_location,
                 :escalate_to_webchat,
                 :filter_prefixes
    end
  end
end
