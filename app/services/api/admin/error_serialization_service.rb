module Api
  module Admin
    class ErrorSerializationService
      DEFAULT_ERROR_STATUS_CODE = 422 # Unprocessable_entity
      STATUS_CODES_FOR_ERRORS = {
        'is already taken' => 409, # Conflict
      }.freeze

      def initialize(model)
        @model = model
      end

      def call
        { errors: }
      end

    private

      def errors
        @model.errors.flat_map do |attribute, errors|
          attribute_errors(attribute, errors)
        end
      end

      def attribute_errors(attribute, messages)
        messages.map do |message|
          attribute_error attribute, message
        end
      end

      def attribute_error(attribute, message)
        {
          status: status_code(message),
          title: message,
          detail: "#{attribute.to_s.humanize} #{message}",
          source: {
            pointer: "/data/attributes/#{attribute}",
          },
        }
      end

      def status_code(message)
        STATUS_CODES_FOR_ERRORS[message] || DEFAULT_ERROR_STATUS_CODE
      end
    end
  end
end
