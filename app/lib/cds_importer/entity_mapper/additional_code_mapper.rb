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
    end
  end
end
