class CdsImporter
  class EntityMapper
    class MeasureConditionMapper < BaseMapper
      self.entity_class = 'MeasureCondition'.freeze

      self.mapping_root = 'Measure'.freeze

      self.mapping_path = 'measureCondition'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate', 'metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :measure_sid,
        "#{mapping_path}.sid" => :measure_condition_sid,
        "#{mapping_path}.measureConditionCode.conditionCode" => :condition_code,
        "#{mapping_path}.conditionSequenceNumber" => :component_sequence_number,
        "#{mapping_path}.conditionDutyAmount" => :condition_duty_amount,
        "#{mapping_path}.monetaryUnit.monetaryUnitCode" => :condition_monetary_unit_code,
        "#{mapping_path}.measurementUnit.measurementUnitCode" => :condition_measurement_unit_code,
        "#{mapping_path}.measurementUnitQualifier.measurementUnitQualifierCode" => :condition_measurement_unit_qualifier_code,
        "#{mapping_path}.measureAction.actionCode" => :action_code,
        "#{mapping_path}.certificate.certificateType.certificateTypeCode" => :certificate_type_code,
        "#{mapping_path}.certificate.certificateCode" => :certificate_code,
      ).freeze
    end
  end
end
