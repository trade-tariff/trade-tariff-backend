module RulesOfOrigin
  class DataSet
    attr_reader :scheme_set, :rule_set, :heading_mappings, :scheme_associations

    class << self
      def load_default
        new(
          default_scheme_set,
          default_rule_set,
          default_heading_mappings,
          default_scheme_associations,
        )
      end

    private

      def default_scheme_set
        RulesOfOrigin::TradingScheme.from_default_file(TradeTariffBackend.service)
      end

      def default_rule_set
        RulesOfOrigin::RuleSet.from_default_file.tap(&:import)
      end

      def default_heading_mappings
        RulesOfOrigin::HeadingMappings.from_default_file.tap do |importer|
          importer.import(skip_invalid_rows: true)
        end
      end

      def default_scheme_associations
        RulesOfOrigin::SchemeAssociations.from_default_file.scheme_associations
      end
    end

    def initialize(scheme_set, rule_set, heading_mappings, scheme_associations)
      @scheme_set = scheme_set
      @rule_set = rule_set
      @heading_mappings = heading_mappings
      @scheme_associations = scheme_associations
    end
  end
end
