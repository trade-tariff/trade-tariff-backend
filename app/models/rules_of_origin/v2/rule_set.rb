# frozen_string_literal: true

module RulesOfOrigin
  module V2
    class RuleSet
      HEADING_FORMAT = %r{\A\d{10}\z}

      attr_accessor :heading,
                    :subdivision,
                    :prefix,
                    :min,
                    :max,
                    :valid

      attr_reader :scheme,
                  :rules

      class << self
        def build_for_scheme(scheme, rule_sets_data)
          rule_sets_data['rule_sets'].map do |rule_set_data|
            new scheme, rule_set_data
          end
        end
      end

      def initialize(scheme, attributes = {})
        @scheme = scheme
        attributes.each do |attribute_name, attribute_value|
          public_send "#{attribute_name}=", attribute_value
        end
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

      def rules=(rules)
        @rules = rules.map(&Rule.method(:new))
      end

      class InvalidHeadingRange < StandardError; end
    end
  end
end
