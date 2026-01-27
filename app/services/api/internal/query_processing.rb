module Api
  module Internal
    module QueryProcessing
      include CustomRegex

      private

      def process_query(term)
        return '' if term.blank?

        term = term.to_s.first(100)

        if (m = cas_number_regex.match(term))
          m[1]
        elsif cus_number_regex.match?(term) && digit_regex.match?(term)
          term
        elsif no_alpha_regex.match?(term) && digit_regex.match?(term)
          term.scan(/\d+/).join
        elsif no_alpha_regex.match?(term) && !digit_regex.match?(term)
          ''
        else
          term.gsub(ignore_brackets_regex, '')
        end
      end

      def parse_date(date)
        return Time.zone.today if date.blank?

        Date.parse(date)
      rescue StandardError
        Time.zone.today
      end
    end
  end
end
