module Beta
  module Search
    class InterceptMessage
      CHAPTER_REGEX = /(?<type>chapter)s? (?<optional>code )?(?<code>[0-9]{1,2})(?<terminator>[.,\s])/i
      HEADING_REGEX = /(?<type>(?<!sub)heading)s? (?<optional>code )?(?<code>[0-9]{4})(?<terminator>[.,\s])/i
      SUBHEADING_REGEX = /(?<type>subheading)s? (?<optional>code )?(?<code>[0-9]{6,8})(?<terminator>[.,\s])/i
      COMMODITY_REGEX = /(?<type>commodity|commodities) (?<optional>code )?(?<code>[0-9]{10})(?<terminator>[.,\s])/i

      GOODS_NOMENCLATURE_LINK_TRANSFORMERS = {
        CHAPTER_REGEX => lambda do |matched_text|
          match = matched_text.match(CHAPTER_REGEX)

          "(#{matched_text[0..-2]})[/chapters/#{match[:code].rjust(2, '0')}]#{match[:terminator]}"
        end,

        HEADING_REGEX => lambda do |matched_text|
          match = matched_text.match(HEADING_REGEX)

          "(#{matched_text[0..-2]})[/headings/#{match[:code]}]#{match[:terminator]}"
        end,

        SUBHEADING_REGEX => lambda do |matched_text|
          match = matched_text.match(SUBHEADING_REGEX)

          "(#{matched_text[0..-2]})[/subheadings/#{match[:code].ljust(10, '0')}-80]#{match[:terminator]}"
        end,

        COMMODITY_REGEX => lambda do |matched_text|
          match = matched_text.match(COMMODITY_REGEX)

          "(#{matched_text[0..-2]})[/commodities/#{match[:code]}]#{match[:terminator]}"
        end,
      }.freeze

      include ContentAddressableId

      content_addressable_fields :term, :message

      attr_accessor :term, :message

      def self.build(search_query)
        query = search_query.downcase

        return unless query.eql?(I18n.t("#{query}.title"))

        result = new
        term = I18n.t("#{query}.title")
        message = I18n.t("#{query}.message")

        result.term = term
        result.message = message.ends_with?('.') ? message : message.concat('.')

        result
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
