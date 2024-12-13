module SnapshotLoaders
  class BaseRegulation < Base
    def self.load(file, batch)
      regs = []

      batch.each do |attributes|
        regs.push({
          base_regulation_role: attributes.dig('BaseRegulation', 'regulationRoleType', 'regulationRoleTypeId'),
          base_regulation_id: attributes.dig('BaseRegulation', 'baseRegulationId'),
          community_code: attributes.dig('BaseRegulation', 'communityCode'),
          regulation_group_id: attributes.dig('BaseRegulation', 'regulationGroup', 'regulationGroupId'),
          published_date: attributes.dig('BaseRegulation', 'publishedDate'),
          officialjournal_number: attributes.dig('BaseRegulation', 'officialjournalNumber'),
          officialjournal_page: attributes.dig('BaseRegulation', 'officialjournalPage'),
          replacement_indicator: attributes.dig('BaseRegulation', 'replacementIndicator'),
          information_text: attributes.dig('BaseRegulation', 'informationText'),
          approved_flag: attributes.dig('BaseRegulation', 'approvedFlag'),
          stopped_flag: attributes.dig('BaseRegulation', 'stoppedFlag'),
          effective_end_date: attributes.dig('BaseRegulation', 'effectiveEndDate'),
          antidumping_regulation_role: attributes.dig('BaseRegulation', 'antidumpingRegulationRole'),
          related_antidumping_regulation_id: attributes.dig('BaseRegulation', 'relatedAntidumpingRegulationId'),
          complete_abrogation_regulation_role: attributes.dig('BaseRegulation', 'completeAbrogationRegulation', 'regulationRoleType', 'regulationRoleTypeId'),
          complete_abrogation_regulation_id: attributes.dig('BaseRegulation', 'completeAbrogationRegulation', 'completeAbrogationRegulationId'),
          explicit_abrogation_regulation_role: attributes.dig('BaseRegulation', 'explicitAbrogationRegulation', 'regulationRoleType', 'regulationRoleTypeId'),
          explicit_abrogation_regulation_id: attributes.dig('BaseRegulation', 'explicitAbrogationRegulation', 'explicitAbrogationRegulationId'),
          validity_start_date: attributes.dig('BaseRegulation', 'validityStartDate'),
          validity_end_date: attributes.dig('BaseRegulation', 'validityEndDate'),
          operation: attributes.dig('BaseRegulation', 'metainfo', 'opType'),
          operation_date: attributes.dig('BaseRegulation', 'metainfo', 'transactionDate'),
          filename: file,
        })
      end

      Object.const_get('BaseRegulation::Operation').multi_insert(regs)
    end
  end
end
