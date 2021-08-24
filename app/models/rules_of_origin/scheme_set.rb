module RulesOfOrigin
  class SchemeSet
    attr_reader :base_path

    def initialize(source_file)
      data = JSON.parse read_file(source_file)

      unless data['scope'] == TradeTariffBackend.service
        raise ScopeDoesNotMatch
      end

      @_schemes = data['schemes'].map(&Scheme.method(:new))
                                 .index_by(&:scheme_code)
                                 .freeze
      @_countries = rebuild_countries_to_schemes_index.freeze
    end

    def schemes
      @_schemes.keys
    end

    def scheme(scheme_code)
      @_schemes[scheme_code] || raise(SchemeNotFound, "Unknown scheme: #{scheme_code}")
    end

    def countries
      @_countries.keys
    end

    def schemes_for_country(country_code)
      @_schemes.values_at(*(@_countries[country_code] || []))
    end

    class ScopeDoesNotMatch < RuntimeError; end

    class InvalidSchemesFile < RuntimeError; end

    class SchemeNotFound < RuntimeError; end

    private

    def read_file(file)
      @source_file = Pathname.new(file)
      unless @source_file.extname == '.json' && @source_file.file? && @source_file.exist?
        raise InvalidSchemesFile, 'Requires a path to a JSON file'
      end

      @base_path = @source_file.dirname
      @source_file.read
    end

    def rebuild_countries_to_schemes_index
      @_schemes.each.with_object({}) do |(scheme_code, scheme), countries|
        scheme.countries.each do |country_code|
          countries[country_code] ||= Set.new
          countries[country_code] << scheme_code
        end
      end
    end
  end
end
