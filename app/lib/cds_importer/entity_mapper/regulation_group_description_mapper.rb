class CdsImporter
  class EntityMapper
    class RegulationGroupDescriptionMapper < BaseMapper
      self.entity_class = 'RegulationGroupDescription'.freeze

      self.mapping_root = 'RegulationGroup'.freeze

      self.mapping_path = 'regulationGroupDescription'.freeze

      self.exclude_mapping = %w[validityStartDate validityEndDate].freeze

      self.entity_mapping = base_mapping.merge(
        'regulationGroupId' => :regulation_group_id,
        "#{mapping_path}.language.languageId" => :language_id,
        "#{mapping_path}.description" => :description,
      ).freeze
    end
  end
end
