class CdsImporter
  class EntityMapper
    class AdditionalCodeTypeMapper < BaseMapper
      self.entity_class = 'AdditionalCodeType'.freeze

      self.mapping_root = 'AdditionalCodeType'.freeze

      self.entity_mapping = base_mapping.merge(
        'applicationCode' => :application_code,
        'additionalCodeTypeId' => :additional_code_type_id,
        'meursingTablePlan.meursingTablePlanId' => :meursing_table_plan_id
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
