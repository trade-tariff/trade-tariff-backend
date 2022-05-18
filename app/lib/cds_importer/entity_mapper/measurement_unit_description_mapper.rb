class CdsImporter
  class EntityMapper
    class MeasurementUnitDescriptionMapper < BaseMapper
      self.entity_class = 'MeasurementUnitDescription'.freeze

      self.mapping_root = 'MeasurementUnit'.freeze

      self.mapping_path = 'measurementUnitDescription'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate', 'metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'measurementUnitCode' => :measurement_unit_code,
        "#{mapping_path}.language.languageId" => :language_id,
        "#{mapping_path}.description" => :description,
      ).freeze
    end
  end
end
