#
# Measurement in nested in to MeasurementUnit.
# I didn't find Measurement in examples. But it looks like Measurement == MeasurementUnit.
# So I decided to map base attrs to MeasurementUnit.
#

class CdsImporter
  class EntityMapper
    class MeasurementMapper < BaseMapper
      self.entity_class = 'Measurement'.freeze

      self.mapping_root = 'MeasurementUnit'.freeze

      self.mapping_path = 'measurementUnitQualifier'.freeze

      self.exclude_mapping = ['metainfo.origin', 'metainfo.opType', 'metainfo.transactionDate', 'validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'measurementUnitCode' => :measurement_unit_code,
        "#{mapping_path}.measurementUnitQualifierCode" => :measurement_unit_qualifier_code,
        'validityStartDate' => :validity_start_date,
        'validityEndDate' => :validity_end_date,
        'metainfo.opType' => :operation,
        'metainfo.transactionDate' => :operation_date,
      ).freeze
    end
  end
end
