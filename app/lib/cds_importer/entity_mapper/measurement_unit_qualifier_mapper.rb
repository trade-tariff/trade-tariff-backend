class CdsImporter
  class EntityMapper
    class MeasurementUnitQualifierMapper < BaseMapper
      self.entity_class = 'MeasurementUnitQualifier'.freeze

      self.mapping_root = 'MeasurementUnitQualifier'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'measurementUnitQualifierCode' => :measurement_unit_qualifier_code,
      ).freeze
    end
  end
end
