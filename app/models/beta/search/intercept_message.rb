module Beta
  module Search
    class InterceptMessage
      INTERCEPT_MESSAGES_SOURCE_PATH = Rails.root.join('data/intercept-messages.yml').freeze

      SECTION_REGEX = /(?<type>section)s? (?<optional>code|position|id)?\s*(?<code>[XVI\d]{0,10})(?<terminator>[.,\s)])?/i
      CHAPTER_REGEX = /(?<type>chapter)s? (?<optional>code )?(?<code>[0-9]{1,2})(?<terminator>[.,\s)])/i
      HEADING_REGEX = /(?<type>(?<!sub)heading)s? (?<optional>code )?(?<code>[0-9]{4})(?<terminator>[.,\s)])/i
      SUBHEADING_REGEX = /(?<type>subheading)s? (?<optional>code )?(?<code>[0-9]{6,8})(?<terminator>[.,\s)])/i
      COMMODITY_REGEX = /(?<type>commodity|commodities) (?<optional>code )?(?<code>[0-9]{10})(?<terminator>[.,\s)])/i

      GOODS_NOMENCLATURE_LINK_TRANSFORMERS = {
        SECTION_REGEX => lambda do |matched_text|
          match = matched_text.match(SECTION_REGEX)

          section_id = RomanNumerals::Converter.to_decimal(match[:code])

          roman_section_id = RomanNumerals::Converter.to_roman(section_id)

          "[section#{roman_section_id}](/sections/#{section_id})#{match[:terminator]}"
        end,

        CHAPTER_REGEX => lambda do |matched_text|
          match = matched_text.match(CHAPTER_REGEX)

          "[#{matched_text[0..-2]}](/chapters/#{match[:code].rjust(2, '0')})#{match[:terminator]}"
        end,

        HEADING_REGEX => lambda do |matched_text|
          match = matched_text.match(HEADING_REGEX)

          "[#{matched_text[0..-2]}](/headings/#{match[:code]})#{match[:terminator]}"
        end,

        SUBHEADING_REGEX => lambda do |matched_text|
          match = matched_text.match(SUBHEADING_REGEX)

          "[#{matched_text[0..-2]}](/subheadings/#{match[:code].ljust(10, '0')}-80)#{match[:terminator]}"
        end,

        COMMODITY_REGEX => lambda do |matched_text|
          match = matched_text.match(COMMODITY_REGEX)

          "[#{matched_text[0..-2]}](/commodities/#{match[:code]})#{match[:terminator]}"
        end,
      }.freeze

      include ContentAddressableId

      content_addressable_fields :term, :message

      attr_accessor :term, :message

      class << self
        def build(search_query)
          normalised_query = normalise_query(search_query)

          message = intercept_messages[normalised_query]

          return nil if message.blank?

          intercept_message = new
          intercept_message.term = normalised_query
          intercept_message.message = normalise_message(message)
          intercept_message
        end

        def intercept_messages
          @intercept_messages ||= YAML.load_file(INTERCEPT_MESSAGES_SOURCE_PATH)
        end

        private

        def normalise_query(search_query)
          search_query.downcase.scan(/\w+/).join(' ')
        end

        def normalise_message(message)
          message.ends_with?('.') ? message : message.concat('.')
        end
      end

      def formatted_message
        return '' if message.blank?

        GOODS_NOMENCLATURE_LINK_TRANSFORMERS.each_with_object(message.dup) do |(regex, transformer), transformed_message|
          transformed_message.gsub!(regex) do |matched_text|
            transformer.call(matched_text)
          end
        end
      end
    end
  end
end
