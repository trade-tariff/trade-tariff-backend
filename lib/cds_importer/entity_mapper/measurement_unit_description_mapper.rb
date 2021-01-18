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
        "#{mapping_path}.description" => :description
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
