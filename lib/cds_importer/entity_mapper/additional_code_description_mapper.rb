class CdsImporter
  class EntityMapper
    class AdditionalCodeDescriptionMapper < BaseMapper
      self.entity_class = 'AdditionalCodeDescription'.freeze

      self.mapping_root = 'AdditionalCode'.freeze

      self.mapping_path = 'additionalCodeDescriptionPeriod.additionalCodeDescription'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'additionalCodeDescriptionPeriod.sid' => :additional_code_description_period_sid,
        "#{mapping_path}.language.languageId" => :language_id,
        'sid' => :additional_code_sid,
        'additionalCodeType.additionalCodeTypeId' => :additional_code_type_id,
        'additionalCodeCode' => :additional_code,
        "#{mapping_path}.description" => :description
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
