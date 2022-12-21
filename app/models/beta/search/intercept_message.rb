module Beta
  module Search
    class InterceptMessage
      INTERCEPT_MESSAGES_SOURCE_PATH = Rails.root.join('data/intercept-messages.yml').freeze

      SECTION_REGEX = /(?<type>section)s? (?<optional>code|position|id)?\s*(?<code>[XVI\d]{0,10})(?<terminator>[.,\s)])?/i
      CHAPTER_REGEX = /(?<type>chapter)s? (?<optional>code )?(?<code>[0-9]{1,2})(?<terminator>[.,\s)])/i
      HEADING_REGEX = /(?<type>(?<!sub)heading)?s? (?<optional>code )?(?<code>[0-9]{4})(?<terminator>[.,\s)])/i
      SUBHEADING_REGEX = /(?<type>subheading)s? (?<optional>code )?(?<code>[0-9]{6,8})(?<terminator>[.,\s)])/i
      COMMODITY_REGEX = /(?<type>commodity|commodities) (?<optional>code )?(?<code>[0-9]{10})(?<terminator>[.,\s)])/i

      GOODS_NOMENCLATURE_LINK_TRANSFORMERS = {
        SECTION_REGEX => lambda do |matched_text|
          match = matched_text.match(SECTION_REGEX)

          section_id = RomanNumerals::Converter.to_decimal(match[:code])
          reference_id = RomanNumerals::Converter.to_roman(section_id)
          section_text = 'section '
          section_text += "#{match[:optional]} " if match[:optional]
          section_text += match[:code]

          ["[#{section_text}](/sections/#{section_id})#{match[:terminator]}", reference_id, :section]
        end,

        CHAPTER_REGEX => lambda do |matched_text|
          match = matched_text.match(CHAPTER_REGEX)

          short_code = match[:code].rjust(2, '0')
          reference_id = "#{short_code}00000000"

          ["[#{matched_text[0..-2]}](/chapters/#{short_code})#{match[:terminator]}", reference_id, :chapter]
        end,

        HEADING_REGEX => lambda do |matched_text|
          match = matched_text.match(HEADING_REGEX)

          short_code = match[:code].scan(/\w+/).first
          reference_id = "#{short_code}000000"

          if match[:type].blank?
            [" [#{short_code}](/headings/#{short_code})#{match[:terminator]}", reference_id, :heading]
          else
            ["[#{matched_text[0..-2]}](/headings/#{short_code})#{match[:terminator]}", reference_id, :heading]
          end
        end,

        SUBHEADING_REGEX => lambda do |matched_text|
          match = matched_text.match(SUBHEADING_REGEX)

          reference_id = match[:code].ljust(10, '0')

          ["[#{matched_text[0..-2]}](/subheadings/#{reference_id}-80)#{match[:terminator]}", reference_id, :subheading]
        end,

        COMMODITY_REGEX => lambda do |matched_text|
          match = matched_text.match(COMMODITY_REGEX)

          reference_id = match[:code]

          ["[#{matched_text[0..-2]}](/commodities/#{reference_id})#{match[:terminator]}", reference_id, :commodity]
        end,
      }.freeze

      include ContentAddressableId

      content_addressable_fields :term, :message

      attr_accessor :term, :message, :formatted_message

      class << self
        def build(search_query)
          normalised_query = normalise_query(search_query)

          message = intercept_messages[normalised_query]

          return nil if message.blank?

          intercept_message = new
          intercept_message.term = normalised_query
          intercept_message.message = normalise_message(message)
          intercept_message.generate_references_and_formatted_message!
          intercept_message
        end

        def intercept_messages
          @intercept_messages ||= YAML.load_file(INTERCEPT_MESSAGES_SOURCE_PATH).transform_keys(&method(:normalise_query))
        end

        def all_references
          @all_references ||= intercept_messages.keys.map(&method(:build)).each_with_object(Hash.new('')) do |intercept_message, acc|
            acc.merge!(intercept_message.references) do |_reference_id, previous_terms, new_term|
              merged = "#{previous_terms} #{new_term}"
              merged.scan(/\w+/).join(' ').downcase
            end
          end
        end

        private

        def normalise_query(search_query)
          search_query.squish.downcase
        end

        def normalise_message(message)
          message.ends_with?('.') ? message : message.concat('.')
        end
      end

      def references
        @references ||= Hash.new('')
      end

      def generate_references_and_formatted_message!
        self.formatted_message = begin
          if message.blank?
            ''
          else
            GOODS_NOMENCLATURE_LINK_TRANSFORMERS.each_with_object(message.dup) do |(regex, transformer), transformed_message|
              transformed_message.gsub!(regex) do |matched_text|
                transformed, reference_id, type = transformer.call(matched_text)

                references[reference_id] = term if type.in?(%i[commodity subheading])

                transformed
              end
            end
          end
        end
      end
    end
  end
end
