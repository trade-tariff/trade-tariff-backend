class CdsImporter
  class EntityMapper
    class ExplicitAbrogationRegulationMapper < BaseMapper
      self.entity_class = 'ExplicitAbrogationRegulation'.freeze

      self.mapping_root = 'ExplicitAbrogationRegulation'.freeze

      self.exclude_mapping = ['metainfo.origin', 'validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'regulationRoleType.regulationRoleTypeId' => :explicit_abrogation_regulation_role,
        'explicitAbrogationRegulationId' => :explicit_abrogation_regulation_id,
        'publishedDate' => :published_date,
        'officialjournalNumber' => :officialjournal_number,
        'officialjournalPage' => :officialjournal_page,
        'replacementIndicator' => :replacement_indicator,
        'abrogationDate' => :abrogation_date,
        'informationText' => :information_text,
        'approvedFlag' => :approved_flag
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
