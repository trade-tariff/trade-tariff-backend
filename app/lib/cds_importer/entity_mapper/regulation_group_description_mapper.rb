class CdsImporter
  class EntityMapper
    class RegulationGroupDescriptionMapper < BaseMapper
      self.entity_class = 'RegulationGroupDescription'.freeze

      self.mapping_root = 'RegulationGroup'.freeze

      self.mapping_path = 'regulationGroupDescription'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'regulationGroupId' => :regulation_group_id,
        "#{mapping_path}.language.languageId" => :language_id,
        "#{mapping_path}.description" => :description
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
