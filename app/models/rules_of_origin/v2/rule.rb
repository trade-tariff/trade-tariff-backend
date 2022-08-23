module RulesOfOrigin
  module V2
    class Rule
      include ContentAddressableId

      content_addressable_fields 'rule', 'original', 'operator', 'rule_class'

      attr_accessor :rule,
                    :original,
                    :operator

      attr_reader :rule_class

      def initialize(attributes = {})
        attributes.each do |attribute_name, attribute_value|
          if attribute_name.to_s == 'class'
            self.rule_class = attribute_value
          elsif respond_to?("#{attribute_name}=")
            public_send "#{attribute_name}=", attribute_value
          end
        end
      end

      def rule_class=(value)
        @rule_class = Array.wrap(value).map(&:to_s).map(&:presence).compact.sort
      end
    end
  end
end
