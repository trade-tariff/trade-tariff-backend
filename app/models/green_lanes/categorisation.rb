# frozen_string_literal: true

module GreenLanes
  class Categorisation
    include ActiveModel::Model

    DEFAULT_JSON = 'data/green_lanes/categories.json'

    attr_accessor :category,
                  :regulation_id,
                  :measure_type_id,
                  :geographical_area,
                  :document_codes,
                  :additional_codes

    class << self
      def load_from_file(file = DEFAULT_JSON)
        source_file = Pathname.new(file)
        unless source_file.extname == '.json' && source_file.file? && source_file.exist?
          raise InvalidFile, 'Requires a path to a JSON file'
        end

        load_from_string File.read(file)
      end

      def load_from_string(data)
        json_array = JSON.parse(data)
        @all = json_array.map { |json| new(json) }
      end

      def all
        @all ||= load_from_file
      end
    end

    class InvalidFile < RuntimeError; end
  end
end
