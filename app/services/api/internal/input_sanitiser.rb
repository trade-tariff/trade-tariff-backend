module Api
  module Internal
    class InputSanitiser
      NON_PRINTABLE = /[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\u200B\u200C\u200D\uFEFF]/

      def initialize(query)
        @query = query
      end

      def call
        return { query: @query.to_s } unless enabled?
        return { query: '' } if @query.blank?

        raw = @query.to_s

        if NON_PRINTABLE.match?(raw)
          return error_response('Query contains invalid characters')
        end

        sanitised = strip_html(raw)
        sanitised = normalise_whitespace(sanitised)

        if sanitised.length > max_length
          return error_response("Query exceeds maximum length of #{max_length} characters")
        end

        { query: sanitised }
      end

      private

      def enabled?
        AdminConfiguration.enabled?('input_sanitiser_enabled')
      end

      def max_length
        AdminConfiguration.integer_value('input_sanitiser_max_length')
      end

      def strip_html(text)
        Rails::HTML5::FullSanitizer.new.sanitize(text)
      end

      def normalise_whitespace(text)
        text.gsub(/\s+/, ' ').strip
      end

      def error_response(detail)
        {
          errors: [
            {
              status: '422',
              title: 'Invalid query',
              detail: detail,
            },
          ],
        }
      end
    end
  end
end
