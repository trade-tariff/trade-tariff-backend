class CdsImporter
  class EntityMapper
    class FullTemporaryStopRegulationMapper < BaseMapper
      self.entity_class = 'FullTemporaryStopRegulation'.freeze

      self.mapping_root = 'FullTemporaryStopRegulation'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'regulationRoleType.regulationRoleTypeId' => :full_temporary_stop_regulation_role,
        'fullTemporaryStopRegulationId' => :full_temporary_stop_regulation_id,
        'publishedDate' => :published_date,
        'officialjournalNumber' => :officialjournal_number,
        'officialjournalPage' => :officialjournal_page,
        'effectiveEndDate' => :effective_enddate,
        'explicitAbrogationRegulation.regulationRoleType.regulationRoleTypeId' => :explicit_abrogation_regulation_role,
        'explicitAbrogationRegulation.explicitAbrogationRegulationId' => :explicit_abrogation_regulation_id,
        'replacementIndicator' => :replacement_indicator,
        'informationText' => :information_text,
        'approvedFlag' => :approved_flag,
      ).freeze
    end
  end
end
