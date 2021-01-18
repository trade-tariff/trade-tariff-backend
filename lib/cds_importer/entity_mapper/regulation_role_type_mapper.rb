class CdsImporter
  class EntityMapper
    class RegulationRoleTypeMapper < BaseMapper
      self.entity_class = 'RegulationRoleType'.freeze

      self.mapping_root = 'RegulationRoleType'.freeze

      self.entity_mapping = base_mapping.merge(
        'regulationRoleTypeId' => :regulation_role_type_id
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
