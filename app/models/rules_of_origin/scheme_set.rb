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

        base_path = source_file.dirname.join source_file.basename(source_file.extname)

        new(base_path, source_file.read)
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

    def read_referenced_file(filename)
      unless valid_referenced_file?(filename)
        raise InvalidReferencedFile, filename
      end

      base_path.join(filename).read
    end

    class InvalidSchemesFile < RuntimeError; end

    class SchemeNotFound < RuntimeError; end

    class CurrentSetAlreadyAssigned < RuntimeError; end

    class InvalidReferencedFile < RuntimeError; end

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

    def build_schemes(schemes_data)
      schemes_data.map(&method(:build_scheme)).index_by(&:scheme_code)
    end

    def build_scheme(scheme_data)
      Scheme.new scheme_data.merge(scheme_set: self)
    end

    def valid_referenced_file?(filename)
      return false if filename.match?(/\.\.+/)

      filename.match?(/\A[a-zA-Z0-9\-_.]+\z/)
    end
  end
end
