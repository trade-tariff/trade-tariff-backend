module RulesOfOrigin
  class DataSet
    attr_reader :scheme_set, :rule_set, :heading_mappings

    class << self
      def load_default
        return load_mocked unless TradeTariffBackend.rules_of_origin_enabled?

        new default_scheme_set, default_rule_set, default_heading_mappings
      end

    private

      def default_scheme_set
        RulesOfOrigin::SchemeSet.from_default_file(TradeTariffBackend.service)
      end

      def default_rule_set
        RulesOfOrigin::RuleSet.from_default_file.tap(&:import)
      end

      def default_heading_mappings
        RulesOfOrigin::HeadingMappings.from_default_file.tap do |importer|
          importer.import(skip_invalid_rows: true)
        end
      end

      # FIXME: Mocked data - to be removed once data loading is turned on

      def load_mocked
        new(mocked_scheme_set, mocked_rule_set, mocked_mappings)
      end

      def mocked_scheme_set
        RulesOfOrigin::SchemeSet.from_file \
          RulesOfOrigin::SchemeSet::DEFAULT_SOURCE_PATH.join('mocked_schemes.json')
      end

      def mocked_rule_set
        RulesOfOrigin::RuleSet.new(
          RulesOfOrigin::RuleSet::DEFAULT_SOURCE_PATH.join('mocked_rules.csv'),
        ).tap(&:import)
      end

      def mocked_mappings
        RulesOfOrigin::HeadingMappings.new(
          RulesOfOrigin::RuleSet::DEFAULT_SOURCE_PATH.join('mocked_mappings.csv'),
        ).tap(&:import)
      end
    end

    def initialize(scheme_set, rule_set, heading_mappings)
      @scheme_set = scheme_set
      @rule_set = rule_set
      @heading_mappings = heading_mappings
    end
  end
end
