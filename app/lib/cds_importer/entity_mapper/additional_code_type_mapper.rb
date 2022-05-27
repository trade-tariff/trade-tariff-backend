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

      before_oplog_inserts do |_xml_node, mapper_instance, model_instance|
        if mapper_instance.destroy_operation?
          additional_code_type_id = model_instance.additional_code_type_id

          cascade_destroy { AdditionalCodeTypeMeasureType.where(additional_code_type_id:) }
          cascade_destroy { AdditionalCodeTypeDescription.where(additional_code_type_id:) }
        end
      end

      delete_missing_entities AdditionalCodeTypeDescriptionMapper,
                              AdditionalCodeTypeMeasureTypeMapper
    end
  end
end
