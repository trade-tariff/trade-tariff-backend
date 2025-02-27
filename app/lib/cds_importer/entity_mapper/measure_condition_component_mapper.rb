class CdsImporter
  class EntityMapper
    class MeasureConditionComponentMapper < BaseMapper
      self.entity_class = 'MeasureConditionComponent'.freeze

      self.mapping_root = 'Measure'.freeze

      self.mapping_path = 'measureCondition.measureConditionComponent'.freeze

      self.exclude_mapping = ['metainfo.origin', 'validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'measureCondition.sid' => :measure_condition_sid,
        "#{mapping_path}.dutyExpression.dutyExpressionId" => :duty_expression_id,
        "#{mapping_path}.dutyAmount" => :duty_amount,
        "#{mapping_path}.monetaryUnit.monetaryUnitCode" => :monetary_unit_code,
        "#{mapping_path}.measurementUnit.measurementUnitCode" => :measurement_unit_code,
        "#{mapping_path}.measurementUnitQualifier.measurementUnitQualifierCode" => :measurement_unit_qualifier_code,
      ).freeze
    end
  end
end
