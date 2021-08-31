# frozen_string_literal: true

module RulesOfOrigin
  class SchemeSet
    DEFAULT_SOURCE_PATH = Rails.root.join('db/rules_of_origin').freeze

    attr_reader :base_path, :links

    class << self
      def from_file(file)
        source_file = Pathname.new(file)
        unless source_file.extname == '.json' && source_file.file? && source_file.exist?
          raise InvalidSchemesFile, 'Requires a path to a JSON file'
        end

        new(source_file.dirname, source_file.read)
      end

      def from_default_file(service)
        from_file DEFAULT_SOURCE_PATH.join("roo_schemes_#{service}.json")
      end
    end

    def initialize(base_path, source_data)
      @base_path = base_path
      data = JSON.parse(source_data)

      @links = build_links(data['links']).freeze
      @_schemes = build_schemes(data['schemes']).freeze
      @_countries = build_countries_to_schemes_index.freeze
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

    class InvalidSchemesFile < RuntimeError; end

    class SchemeNotFound < RuntimeError; end

    class CurrentSetAlreadyAssigned < RuntimeError; end

  private

    def build_countries_to_schemes_index
      @_schemes.each.with_object({}) do |(scheme_code, scheme), countries|
        scheme.countries.each do |country_code|
          countries[country_code] ||= Set.new
          countries[country_code] << scheme_code
        end
      end
    end

    def build_links(links)
      links.map(&Link.method(:new_with_check)).compact
    end

    def build_schemes(schemes)
      schemes.map(&Scheme.method(:new)).index_by(&:scheme_code)
    end
  end
end
