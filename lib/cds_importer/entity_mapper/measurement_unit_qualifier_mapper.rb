class CdsImporter
  class EntityMapper
    class MeasurementUnitQualifierMapper < BaseMapper
      self.entity_class = 'MeasurementUnitQualifier'.freeze

      self.mapping_root = 'MeasurementUnitQualifier'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'measurementUnitQualifierCode' => :measurement_unit_qualifier_code
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
