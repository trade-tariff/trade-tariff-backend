class CdsImporter
  class EntityMapper
    class RegulationGroupMapper < BaseMapper
      self.entity_class = 'RegulationGroup'.freeze

      self.mapping_root = 'RegulationGroup'.freeze

      self.entity_mapping = base_mapping.merge(
        'regulationGroupId' => :regulation_group_id,
      ).freeze
    end
  end
end
