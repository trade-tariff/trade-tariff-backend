class CdsImporter
  class EntityMapper
    class RegulationRoleTypeMapper < BaseMapper
      self.entity_class = 'RegulationRoleType'.freeze

      self.mapping_root = 'RegulationRoleType'.freeze

      self.entity_mapping = base_mapping.merge(
        'regulationRoleTypeId' => :regulation_role_type_id,
      ).freeze
    end
  end
end
