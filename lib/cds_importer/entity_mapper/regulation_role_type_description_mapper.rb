class CdsImporter
  class EntityMapper
    class RegulationRoleTypeDescriptionMapper < BaseMapper
      self.entity_class = 'RegulationRoleTypeDescription'.freeze

      self.mapping_root = 'RegulationRoleType'.freeze

      self.mapping_path = 'regulationRoleTypeDescription'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'regulationRoleTypeId' => :regulation_role_type_id,
        "#{mapping_path}.description" => :description,
        "#{mapping_path}.language.languageId" => :language_id
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
