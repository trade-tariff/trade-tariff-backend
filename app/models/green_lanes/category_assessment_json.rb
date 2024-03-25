# frozen_string_literal: true

module GreenLanes
  class CategoryAssessmentJson
    include ActiveModel::Model
    include ContentAddressableId

    DEFAULT_JSON = if Rails.env.development?
                     'data/green_lanes/categories.json'
                   else
                     'data/green_lanes/stub_categories.json'
                   end

    CATEGORISATION_OBJECT_KEY = 'data/categorisation/categories.json'

    content_addressable_fields 'regulation_id', 'measure_type_id', 'geographical_area_id', 'document_codes', 'additional_codes'

    attr_accessor :category,
                  :regulation_id,
                  :measure_type_id,
                  :geographical_area_id,
                  :document_codes,
                  :additional_codes,
                  :theme

    class << self
      def load_category_assessment
        if Rails.application.config.persistence_bucket.present?
          load_from_s3
        else
          load_from_file
        end
      end

      def load_from_s3
        data = Rails.application.config.persistence_bucket.object(CATEGORISATION_OBJECT_KEY).get.body.read
        load_from_string data
      rescue Aws::S3::Errors::NoSuchKey => e
        raise InvalidFile, "File not found in S3 (#{e.message})"
      end

      def load_from_file(file = DEFAULT_JSON)
        source_file = Pathname.new(file)
        unless source_file.extname == '.json' && source_file.file? && source_file.exist?
          raise InvalidFile, 'Requires a path to a JSON file'
        end

        load_from_string File.read(file)
      end

      def load_from_string(data)
        json_array = JSON.parse(data)
        @all = json_array.map { |json| new(json).tap(&:id).tap(&:freeze) }
      end

      def all
        @all ||= load_category_assessment
      end

      def filter(regulation_id:, measure_type_id:, geographical_area: nil)
        return [] if regulation_id.blank? || measure_type_id.blank?

        all.select { |cat| cat.match?(regulation_id:, measure_type_id:, geographical_area:) }
      end
    end

    def match?(regulation_id:, measure_type_id:, geographical_area: nil)
      regulation_id == self.regulation_id &&
        measure_type_id == self.measure_type_id &&
        (geographical_area == geographical_area_id ||
          geographical_area.blank? ||
          geographical_area_id == GeographicalArea::ERGA_OMNES_ID)
    end

    def exemptions
      certificates + additional_code_instances
    end

    def certificates
      Certificate
        .actual
        .where(Sequel.function(:concat, :certificate_type_code, :certificate_code) => document_codes)
        .all
    end

    def additional_code_instances
      AdditionalCode
        .actual
        .where(Sequel.function(:concat, :additional_code_type_id, :additional_code) => additional_codes)
        .all
    end

    def excluded_geographical_areas
      []
    end

    def excluded_geographical_area_ids
      excluded_geographical_areas.map(&:geographical_area_id)
    end

    def geographical_area
      GeographicalArea.where(geographical_area_id:).take
    end

    class InvalidFile < RuntimeError; end
  end
end
