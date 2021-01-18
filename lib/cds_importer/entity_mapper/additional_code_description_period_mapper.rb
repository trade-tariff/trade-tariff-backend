class CdsImporter
  class EntityMapper
    class AdditionalCodeDescriptionPeriodMapper < BaseMapper
      self.entity_class = 'AdditionalCodeDescriptionPeriod'.freeze

      self.mapping_root = 'AdditionalCode'.freeze

      self.mapping_path = 'additionalCodeDescriptionPeriod'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        "#{mapping_path}.sid" => :additional_code_description_period_sid,
        'sid' => :additional_code_sid,
        'additionalCodeType.additionalCodeTypeId' => :additional_code_type_id,
        'additionalCodeCode' => :additional_code
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
