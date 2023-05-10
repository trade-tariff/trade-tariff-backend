module RulesOfOrigin
  module V2
    class RuleSet
      include ContentAddressableId

      content_addressable_fields 'scheme_code', 'heading', 'min', 'max', 'rule_ids'

      delegate :scheme_code, to: :scheme

      HEADING_FORMAT = %r{\A\d{10}\z}

      attr_accessor :scheme,
                    :heading,
                    :prefix,
                    :min,
                    :max,
                    :valid,
                    :footnote_definitions

      attr_reader :rules, :subdivision

      class << self
        def build_for_scheme(scheme, rule_sets_data)
          footnote_definitions = rule_sets_data['footnote_definitions'] || {}

          rule_sets_data['rule_sets']
            .map { |rs| new rs.merge(scheme:, footnote_definitions:) }
            .select(&:valid?)
        end
      end

      def initialize(attributes = {})
        attributes = attributes.stringify_keys
        self.footnote_definitions = attributes.delete(:footnote_definitions) || {}

        attributes.each do |attribute_name, attribute_value|
          if respond_to?("#{attribute_name}=")
            public_send "#{attribute_name}=", attribute_value
          end
        end
      end

      def subdivision=(value)
        @subdivision = value.presence
      end

      def headings_range
        @headings_range ||= begin
          unless min.is_a?(Integer) || min.to_s.match?(HEADING_FORMAT)
            raise InvalidHeadingRange, "Minimum is invalid (#{min})"
          end

          unless max.is_a?(Integer) || max.to_s.match?(HEADING_FORMAT)
            raise InvalidHeadingRange, "Maximum is invalid (#{min})"
          end

          Range.new(min.to_i, max.to_i)
        end
      end

      def valid?
        !!headings_range
      rescue InvalidHeadingRange
        false
      end

      def rules=(rules)
        @rules = rules.map { |data| Rule.new data.merge(rule_set: self) }
      end

      def for_subheading?(code)
        padded_code = "#{code}#{'0' * (10 - code.to_s.length)}"

        headings_range.include? padded_code.to_i
      end

      def rule_ids
        rules.map(&:id)
      end

      class InvalidHeadingRange < StandardError; end
    end
  end
end
