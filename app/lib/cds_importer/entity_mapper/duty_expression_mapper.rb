class CdsImporter
  class EntityMapper
    class DutyExpressionMapper < BaseMapper
      self.entity_class = 'DutyExpression'.freeze

      self.mapping_root = 'DutyExpression'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'dutyExpressionId' => :duty_expression_id,
        'dutyAmountApplicabilityCode' => :duty_amount_applicability_code,
        'measurementUnitApplicabilityCode' => :measurement_unit_applicability_code,
        'monetaryUnitApplicabilityCode' => :monetary_unit_applicability_code,
      ).freeze
    end
  end
end
