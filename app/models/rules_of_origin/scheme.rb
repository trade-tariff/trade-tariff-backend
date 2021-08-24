module RulesOfOrigin
  class Scheme
    include ActiveModel::Model

    attr_accessor :scheme_code, :title, :introductory_notes_file, :fta_intro_file,
                  :countries, :rule_offset, :footnote

    attr_reader :links, :explainers

    class << self
      def load_from_file(file)
        data = JSON.parse read_file(file)

        unless data['scope'] == TradeTariffBackend.service
          raise ScopeDoesNotMatch
        end

        self.schemes = data['schemes'].map(&method(:new)).index_by(&:scheme_code).freeze
        self.countries_to_schemes = rebuild_countries_to_schemes_index.freeze
      end

      def find(scheme_code)
        schemes[scheme_code]
      end

      def for_country(country_code)
        countries_to_schemes[country_code] || Set.new
      end

    private

      attr_accessor :schemes, :countries_to_schemes

      def rebuild_countries_to_schemes_index
        schemes.each.with_object({}) do |(scheme_code, scheme), countries|
          scheme.countries.each do |country_code|
            countries[country_code] ||= Set.new
            countries[country_code] << scheme_code
          end
        end
      end

      def read_file(file)
        source_file = Pathname.new(file)
        unless source_file.extname == '.json' && source_file.file? && source_file.exist?
          raise InvalidSchemesFile, 'Requires a path to a JSON file'
        end

        source_file.read
      end
    end

    class SchemesNotLoaded < RuntimeError; end

    class ScopeDoesNotMatch < RuntimeError; end

    class InvalidSchemesFile < RuntimeError; end

    def links=(links_data)
      @links = Array.wrap(links_data)
                    .map(&Link.method(:new_with_check))
                    .compact
    end

    def explainers=(explainers_data)
      @explainers = Array.wrap(explainers_data)
                         .map(&Explainer.method(:new_with_check))
                         .compact
    end
  end
end
