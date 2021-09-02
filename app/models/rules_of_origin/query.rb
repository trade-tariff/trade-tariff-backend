module RulesOfOrigin
  class Query
    attr_reader :heading_code, :country_code

    delegate :scheme_set, :rule_set, :heading_mappings, to: :@data_set

    def initialize(data_set, heading_code, country_code)
      @data_set = data_set
      @heading_code = heading_code
      @country_code = country_code
    end

    def rules
      id_rules.map(&rule_set.method(:rule))
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

    private

    def id_rules
      schemes_and_their_id_rules.values.flatten.uniq
    end

    def schemes_and_their_id_rules
      @schemes_and_their_id_rules ||=
        heading_mappings.for_heading_and_schemes(heading_code, scheme_codes)
    end
  end
end
