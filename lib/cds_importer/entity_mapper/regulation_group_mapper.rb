class CdsImporter
  class EntityMapper
    class RegulationGroupMapper < BaseMapper
      self.entity_class = 'RegulationGroup'.freeze

      self.mapping_root = 'RegulationGroup'.freeze

      self.entity_mapping = base_mapping.merge(
        'regulationGroupId' => :regulation_group_id
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
