class CdsImporter
  class EntityMapper
    class ModificationRegulationMapper < BaseMapper
      self.entity_class = 'ModificationRegulation'.freeze

      self.mapping_root = 'ModificationRegulation'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'modificationRegulationId' => :modification_regulation_id,
        'publishedDate' => :published_date,
        'officialjournalNumber' => :officialjournal_number,
        'officialjournalPage' => :officialjournal_page,
        'baseRegulation.baseRegulationId' => :base_regulation_id,
        'replacementIndicator' => :replacement_indicator,
        'informationText' => :information_text,
        'effectiveEndDate' => :effective_end_date,
        'approvedFlag' => :approved_flag,
        'stoppedFlag' => :stopped_flag,
        'regulationRoleType.regulationRoleTypeId' => :modification_regulation_role,
        'baseRegulation.regulationRoleType.regulationRoleTypeId' => :base_regulation_role,
        'explicitAbrogationRegulation.regulationRoleType.regulationRoleTypeId' => :explicit_abrogation_regulation_role,
        'explicitAbrogationRegulation.explicitAbrogationRegulationId' => :explicit_abrogation_regulation_id,
        'completeAbrogationRegulation.regulationRoleType.regulationRoleTypeId' => :complete_abrogation_regulation_role,
        'completeAbrogationRegulation.completeAbrogationRegulationId' => :complete_abrogation_regulation_id,
      ).freeze
    end
  end
end
