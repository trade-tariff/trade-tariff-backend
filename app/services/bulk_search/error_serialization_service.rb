module BulkSearch
  class ErrorSerializationService
    DEFAULT_ERROR_STATUS_CODE = 422 # Unprocessable_entity

    def initialize(searches)
      @searches = searches
    end

    def call
      { errors: }
    end

    private

    def errors
      @searches.each_with_object([]) do |search, acc|
        search.errors.messages.each do |attribute, errors|
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
        source: {
          pointer: "/data/attributes/#{attribute}",
        },
      }
    end
  end
end
