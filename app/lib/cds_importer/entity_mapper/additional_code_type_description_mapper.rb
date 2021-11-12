class CdsImporter
  class EntityMapper
    class AdditionalCodeTypeDescriptionMapper < BaseMapper
      self.entity_class = 'AdditionalCodeTypeDescription'.freeze

      self.mapping_root = 'AdditionalCodeType'.freeze

      self.mapping_path = 'additionalCodeTypeDescription'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'additionalCodeTypeId' => :additional_code_type_id,
        "#{mapping_path}.language.languageId" => :language_id,
        "#{mapping_path}.description" => :description
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
