module Api
  module Beta
    class InterceptMessageSerializer
      include JSONAPI::Serializer

      set_type :intercept_message

      attributes :term,
                 :message,
                 :formatted_message
    end
  end
end
