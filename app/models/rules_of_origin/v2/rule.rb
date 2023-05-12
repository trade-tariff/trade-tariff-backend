module RulesOfOrigin
  module V2
    class Rule
      include ContentAddressableId

      content_addressable_fields 'rule', 'original', 'operator', 'rule_class'

      attr_accessor :rule,
                    :original,
                    :operator,
                    :rule_set

      attr_reader :rule_class

      def initialize(attributes = {})
        attributes = attributes.symbolize_keys

        self.rule_set = attributes.delete(:rule_set)
        self.rule_class = attributes.delete(:class)

        attributes.each do |attribute_name, attribute_value|
          next unless respond_to?("#{attribute_name}=")

          public_send "#{attribute_name}=", attribute_value
        end
      end

      def rule_class=(value)
        @rule_class = Array.wrap(value).map(&:to_s).select(&:presence).sort
      end

      def footnotes
        @footnotes ||= []
      end

      def footnotes=(value)
        @footnotes = Array.wrap(value)
                          .map(&:to_s)
                          .select(&:presence)
                          .map { |key| rule_set.footnote_definitions[key] }
                          .compact
      end
    end
  end
end
