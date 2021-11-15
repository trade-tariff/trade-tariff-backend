class CdsImporter
  class EntityMapper
    class MeasurementUnitQualifierDescriptionMapper < BaseMapper
      self.entity_class = 'MeasurementUnitQualifierDescription'.freeze

      self.mapping_root = 'MeasurementUnitQualifier'.freeze

      self.mapping_path = 'measurementUnitQualifierDescription'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate', 'metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'measurementUnitQualifierCode' => :measurement_unit_qualifier_code,
        "#{mapping_path}.description" => :description,
        "#{mapping_path}.language.languageId" => :language_id
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
