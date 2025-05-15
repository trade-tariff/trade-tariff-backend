module Api
  module User
    class ErrorSerializationService
      def serialized_errors(errors)
        errors = Array.wrap(errors).flat_map do |error|
          if error.key?(:error)
            { detail: error[:error] }
          else
            error.flat_map do |attribute, message|
              { title: attribute, detail: message }
            end
          end
        end
        { errors: }.to_json
      end
    end
  end
end
