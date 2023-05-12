# frozen_string_literal: true

module RulesOfOrigin
  class Query
    HEADING_CHECKER = /\A\d{6}\z/
    COUNTRY_CHECKER = /\A[A-Z]{2}\z/
    SUPPORTED_FILTERS = %w[has_article].freeze

    attr_reader :heading_code, :country_code, :filter

    delegate :scheme_set, :rule_set, :heading_mappings, to: :@data_set

    def initialize(data_set, heading_code, country_code, filter)
      @data_set = data_set
      @heading_code = heading_code.to_s.slice(0, 6)
      @country_code = country_code.to_s.upcase
      validate!

      self.filter = filter if filter
    end

    def rules
      return {} unless querying_for_rules?

      schemes_and_their_id_rules.transform_values do |id_rules|
        # convert the id_rules from the mapping to Rule instances loaded from
        # the RuleSet
        rule_set.rules_for_ids(id_rules)
      end
    end

    def schemes
      @schemes ||= if querying_for_rules?
                     scheme_set.schemes_for_country(country_code)
                   elsif filtering_schemes?
                     scheme_set.schemes_for_filter(**filter.symbolize_keys)
                   else
                     scheme_set.all_schemes
                   end
    end

    def scheme_codes
      schemes.map(&:scheme_code)
    end

    def links
      scheme_set.links + schemes.map(&:links).flatten
    end

    def scheme_rule_sets
      return {} unless querying_for_rules?

      schemes.index_by(&:scheme_code)
             .transform_values { |sc| sc.rule_sets_for_subheading(@heading_code) }
    end

    def querying_for_rules?
      heading_code.present? && country_code.present?
    end

    def filtering_schemes?
      !filter.nil?
    end

    class InvalidParams < ArgumentError; end
    class InvalidFilter < ArgumentError; end

    private

    def filter=(filter)
      raise InvalidFilter unless filter.is_a?(Hash)
      raise InvalidFilter unless filter.keys.all?(&SUPPORTED_FILTERS.method(:include?))

      @filter = filter
    end

    def schemes_and_their_id_rules
      @schemes_and_their_id_rules ||=
        heading_mappings.for_heading_and_schemes(heading_code, scheme_codes)
    end

    def validate!
      if heading_code.present? || country_code.present?
        raise InvalidParams unless HEADING_CHECKER.match?(heading_code)
        raise InvalidParams unless COUNTRY_CHECKER.match?(country_code)
      end
    end
  end
end
