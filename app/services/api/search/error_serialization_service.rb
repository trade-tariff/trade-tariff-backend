module Api
  module Search
    class ErrorSerializationService
      DEFAULT_ERROR_STATUS_CODE = 422 # Unprocessable_entity

      def initialize(records)
        @records = Array.wrap(records)
      end

      def call
        { errors: }
      end

      private

      def errors
        @records.each_with_object([]) do |record, acc|
          record.errors.messages.each do |attribute, errors|
            errors.each do |error|
              acc << attribute_error(attribute, error)
            end
          end
        end
      end

      def attribute_error(attribute, message)
        {
          status: DEFAULT_ERROR_STATUS_CODE,
          title: message,
          detail: "#{attribute.to_s.humanize} #{message}",
        }
      end
    end
  end
end
