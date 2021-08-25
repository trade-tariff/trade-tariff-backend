module Api
  module V1
    class ErrorSerializationService

      def serialized_errors(errors)
        errors.to_json
      end
    end
  end
end
