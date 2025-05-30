module RulesOfOrigin
  class SchemeAssociations
    DEFAULT_SOURCE_PATH = Rails.root.join('lib/rules_of_origin').freeze
    DEFAULT_FILE = 'roo_scheme_area_associations_220315.json'.freeze

    class << self
      def from_default_file
        new DEFAULT_SOURCE_PATH.join(DEFAULT_FILE)
      end
    end

    def initialize(source_file)
      @source_file = source_file
    end

    def scheme_associations
      @scheme_associations ||= JSON.parse(File.read(@source_file))
    end
  end
end
