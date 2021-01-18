class CdsImporter
  class EntityMapper
    class ProrogationRegulationMapper < BaseMapper
      self.entity_class = 'ProrogationRegulation'.freeze

      self.mapping_root = 'ProrogationRegulation'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate', 'metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'prorogationRegulationId' => :prorogation_regulation_id,
        'regulationRoleType.regulationRoleTypeId' => :prorogation_regulation_role,
        'publishedDate' => :published_date,
        'officialjournalNumber' => :officialjournal_number,
        'officialjournalPage' => :officialjournal_page,
        'replacementIndicator' => :replacement_indicator,
        'informationText' => :information_text,
        'approvedFlag' => :approved_flag
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
