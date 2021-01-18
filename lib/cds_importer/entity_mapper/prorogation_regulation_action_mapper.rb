class CdsImporter
  class EntityMapper
    class ProrogationRegulationActionMapper < BaseMapper
      self.entity_class = 'ProrogationRegulationAction'.freeze

      self.mapping_root = 'ProrogationRegulation'.freeze

      self.mapping_path = 'prorogationRegulationAction'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate', 'metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'regulationRoleType.regulationRoleTypeId' => :prorogation_regulation_role,
        'prorogationRegulationId' => :prorogation_regulation_id,
        "#{mapping_path}.prorogatedRegulationRole" => :prorogated_regulation_role,
        "#{mapping_path}.prorogatedRegulationId" => :prorogated_regulation_id,
        "#{mapping_path}.prorogatedDate" => :prorogated_date
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
