class CdsImporter
  class EntityMapper
    class CompleteAbrogationRegulationMapper < BaseMapper
      self.entity_class = 'CompleteAbrogationRegulation'.freeze

      self.mapping_root = 'CompleteAbrogationRegulation'.freeze

      self.exclude_mapping = ['metainfo.origin', 'validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'regulationRoleType.regulationRoleTypeId' => :complete_abrogation_regulation_role,
        'completeAbrogationRegulationId' => :complete_abrogation_regulation_id,
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
