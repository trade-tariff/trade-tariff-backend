class CdsImporter
  class EntityMapper
    class RegulationRoleTypeDescriptionMapper < BaseMapper
      self.entity_class = 'RegulationRoleTypeDescription'.freeze

      self.mapping_root = 'RegulationRoleType'.freeze

      self.mapping_path = 'regulationRoleTypeDescription'.freeze

      self.exclude_mapping = %w[validityStartDate validityEndDate].freeze

      self.entity_mapping = base_mapping.merge(
        'regulationRoleTypeId' => :regulation_role_type_id,
        "#{mapping_path}.description" => :description,
        "#{mapping_path}.language.languageId" => :language_id,
      ).freeze
    end
  end
end
