class CdsImporter
  class EntityMapper
    class AdditionalCodeTypeMapper < BaseMapper
      self.entity_class = 'AdditionalCodeType'.freeze

      self.mapping_root = 'AdditionalCodeType'.freeze

      self.entity_mapping = base_mapping.merge(
        'applicationCode' => :application_code,
        'additionalCodeTypeId' => :additional_code_type_id,
        'meursingTablePlan.meursingTablePlanId' => :meursing_table_plan_id,
      ).freeze
    end
  end
end
