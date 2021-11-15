#
# MeasureConditionComponent is nested in to MeasureCondition.
# MeasureCondition is nested in to Measure.
#

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
        "#{mapping_path}.measurementUnitQualifier.measurementUnitQualifierCode" => :measurement_unit_qualifier_code
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
