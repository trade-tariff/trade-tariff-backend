class CdsImporter
  class EntityMapper
    class BaseRegulationMapper < BaseMapper
      self.entity_class = 'BaseRegulation'.freeze

      self.mapping_root = 'BaseRegulation'.freeze

      self.entity_mapping = base_mapping.merge(
        'regulationRoleType.regulationRoleTypeId' => :base_regulation_role,
        'baseRegulationId' => :base_regulation_id,
        'communityCode' => :community_code,
        'regulationGroup.regulationGroupId' => :regulation_group_id,
        'replacementIndicator' => :replacement_indicator,
        'stoppedFlag' => :stopped_flag,
        'approvedFlag' => :approved_flag,
        'informationText' => :information_text,
        'publishedDate' => :published_date,
        'officialjournalNumber' => :officialjournal_number,
        'officialjournalPage' => :officialjournal_page,
        'effectiveEndDate' => :effective_end_date,
        'antidumpingRegulationRole' => :antidumping_regulation_role,
        'relatedAntidumpingRegulationId' => :related_antidumping_regulation_id,
        'completeAbrogationRegulation.regulationRoleType.regulationRoleTypeId' => :complete_abrogation_regulation_role,
        'completeAbrogationRegulation.completeAbrogationRegulationId' => :complete_abrogation_regulation_id,
        'explicitAbrogationRegulation.regulationRoleType.regulationRoleTypeId' => :explicit_abrogation_regulation_role,
        'explicitAbrogationRegulation.explicitAbrogationRegulationId' => :explicit_abrogation_regulation_id,
      ).freeze
    end
  end
end
