# frozen_string_literal: true

module RulesOfOrigin
  class Query
    HEADING_CHECKER = /\A\d{6}\z/
    COUNTRY_CHECKER = /\A[A-Z]{2}\z/

    attr_reader :heading_code, :country_code

    delegate :scheme_set, :rule_set, :heading_mappings, to: :@data_set

    def initialize(data_set, heading_code, country_code)
      @data_set = data_set
      @heading_code = heading_code.to_s.slice(0, 6)
      @country_code = country_code.to_s.upcase
      validate!
    end

    def rules
      schemes_and_their_id_rules.transform_values do |id_rules|
        # convert the id_rules from the mapping to Rule instances loaded from
        # the RuleSet
        rule_set.rules_for_ids(id_rules)
      end
    end

    def schemes
      @schemes ||= scheme_set.schemes_for_country(country_code)
    end

    def scheme_codes
      schemes.map(&:scheme_code)
    end

    def links
      scheme_set.links + schemes.map(&:links).flatten
    end

    class InvalidParams < ArgumentError; end

    private

    def schemes_and_their_id_rules
      @schemes_and_their_id_rules ||=
        heading_mappings.for_heading_and_schemes(heading_code, scheme_codes)
    end

    def validate!
      raise InvalidParams unless HEADING_CHECKER.match?(heading_code)
      raise InvalidParams unless COUNTRY_CHECKER.match?(country_code)
    end
  end
end
