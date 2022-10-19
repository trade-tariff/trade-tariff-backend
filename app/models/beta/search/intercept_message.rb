module Beta
  module Search
    class InterceptMessage
      SECTION_REGEX = /(?<type>section)s? (?<optional>code|position|id)?\s*(?<code>[XVI\d]{0,10})(?<terminator>[.,\s)])?/i
      CHAPTER_REGEX = /(?<type>chapter)s? (?<optional>code )?(?<code>[0-9]{1,2})(?<terminator>[.,\s)])/i
      HEADING_REGEX = /(?<type>(?<!sub)heading)s? (?<optional>code )?(?<code>[0-9]{4})(?<terminator>[.,\s)])/i
      SUBHEADING_REGEX = /(?<type>subheading)s? (?<optional>code )?(?<code>[0-9]{6,8})(?<terminator>[.,\s)])/i
      COMMODITY_REGEX = /(?<type>commodity|commodities) (?<optional>code )?(?<code>[0-9]{10})(?<terminator>[.,\s)])/i

      GOODS_NOMENCLATURE_LINK_TRANSFORMERS = {
        SECTION_REGEX => lambda do |matched_text|
          match = matched_text.match(SECTION_REGEX)

          # code could be Roman (XV) or Decimal (15) format
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

      def self.build(search_query)
        query = search_query.downcase

        return if I18n.t("#{query}.message", default: nil).blank?

        intercept_message = new

        message = I18n.t("#{query}.message")
        message = message.ends_with?('.') ? message : message.concat('.')

        intercept_message.term = query
        intercept_message.message = message

        intercept_message
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
