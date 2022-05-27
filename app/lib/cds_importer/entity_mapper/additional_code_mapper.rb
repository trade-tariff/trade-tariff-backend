class CdsImporter
  class EntityMapper
    class AdditionalCodeMapper < BaseMapper
      self.entity_class = 'AdditionalCode'.freeze

      self.mapping_root = 'AdditionalCode'.freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :additional_code_sid,
        'additionalCodeType.additionalCodeTypeId' => :additional_code_type_id,
        'additionalCodeCode' => :additional_code,
      ).freeze

      before_oplog_inserts do |_xml_node, mapper_instance, model_instance|
        if mapper_instance.destroy_operation?
          additional_code_sid = model_instance.additional_code_sid

          instrument_cascade_destroy { FootnoteAssociationAdditionalCode.where(additional_code_sid:) }
          instrument_cascade_destroy { AdditionalCodeDescriptionPeriod.where(additional_code_sid:) }
        end
      end

      delete_missing_entities FootnoteAssociationAdditionalCodeMapper,
                              AdditionalCodeDescriptionPeriodMapper
    end
  end
end
