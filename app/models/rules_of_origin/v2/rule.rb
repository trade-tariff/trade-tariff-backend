# frozen_string_literal: true

module RulesOfOrigin
  module V2
    class Rule
      attr_accessor :rule,
                    :original,
                    :rule_class,
                    :operator

      def initialize(attributes = {})
        attributes.each do |attribute_name, attribute_value|
          if attribute_name == 'class'
            self.rule_class = attribute_value
          else
            public_send "#{attribute_name}=", attribute_value
          end
        end
      end
    end
  end
end
