# frozen_string_literal: true

module RulesOfOrigin
  class SchemeSet
    # Scheme in this context is the Trading Scheme and not a scheme that provide a validation
    DEFAULT_SOURCE_PATH = Rails.root.join('db/rules_of_origin').freeze

    attr_reader :base_path, :links, :proof_urls

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

      @proof_urls = data['proof_urls'] || {}
      @_schemes = build_schemes(data['schemes']).freeze
      @_countries = build_countries_to_schemes_index.freeze
    end

    def schemes
      todays_schemes.keys
    end

    def scheme(scheme_code)
      todays_schemes[scheme_code] || raise(SchemeNotFound, "Unknown scheme: #{scheme_code}")
    end

    def countries
      @_countries.keys
    end

    def schemes_for_country(country_code)
      todays_schemes.values_at(*(@_countries[country_code] || [])).compact
    end

    def all_schemes
      todays_schemes.values
    end

    def schemes_for_filter(has_article: nil)
      filtered_schemes = all_schemes.dup

      if has_article
        filtered_schemes.select! { |scheme| scheme.has_article?(has_article) }
      end

      filtered_schemes
    end

    def read_referenced_file(*path_components)
      unless path_components.many? &&
          path_components.all?(&method(:valid_referenced_file?))
        raise InvalidReferencedFile, path_components.inspect
      end

      base_path.join(path_components.map(&:to_s).join('/')).read
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

    def build_schemes(schemes_data)
      schemes_data.map(&method(:build_scheme))
                  .index_by(&:scheme_code)
    end

    def build_scheme(scheme_data)
      Scheme.new scheme_data.merge(scheme_set: self)
    end

    def valid_referenced_file?(filename)
      return false if filename.match?(/\.\.+/)

      filename.match?(/\A[a-zA-Z0-9\-_.]+\z/)
    end

    def todays_schemes
      @_schemes.select { |_code, scheme| scheme.valid_for_today? }
    end
  end
end
