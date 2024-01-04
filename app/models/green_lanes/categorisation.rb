# frozen_string_literal: true

module GreenLanes
  class Categorisation
    include ActiveModel::Model
    include ContentAddressableId

    DEFAULT_JSON = if Rails.env.development?
                     'data/green_lanes/categories.json'
                   else
                     'data/green_lanes/stub_categories.json'
                   end

    content_addressable_fields 'regulation_id', 'measure_type_id', 'geographical_area', 'document_codes', 'additional_codes'

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

      def filter(regulation_id:, measure_type_id:, geographical_area: nil)
        return [] if regulation_id.blank? || measure_type_id.blank?

        all.select { |c| c.match?(regulation_id:, measure_type_id:, geographical_area:) }
      end
    end

    def match?(regulation_id:, measure_type_id:, geographical_area: nil)
      regulation_id == self.regulation_id &&
        measure_type_id == self.measure_type_id &&
        (geographical_area.nil? || geographical_area == self.geographical_area)
    end

    class InvalidFile < RuntimeError; end
  end
end
