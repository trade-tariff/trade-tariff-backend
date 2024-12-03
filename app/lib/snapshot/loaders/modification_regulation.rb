module Loaders
  class ModificationRegulation < Base
    def self.load(file, batch)
      regs = []

      batch.each do |attributes|
        regs.push({
                    modification_regulation_id: attributes.dig('ModificationRegulation', 'modificationRegulationId'),
                    modification_regulation_role: attributes.dig('ModificationRegulation', 'regulationRoleType', 'regulationRoleTypeId'),
                    base_regulation_id: attributes.dig('ModificationRegulation', 'baseRegulation', 'baseRegulationId'),
                    base_regulation_role: attributes.dig('ModificationRegulation', 'baseRegulation', 'regulationRoleType', 'regulationRoleTypeId'),
                    published_date: attributes.dig('ModificationRegulation', 'publishedDate'),
                    officialjournal_number: attributes.dig('ModificationRegulation', 'officialjournalNumber'),
                    officialjournal_page: attributes.dig('ModificationRegulation', 'officialjournalPage'),
                    replacement_indicator: attributes.dig('ModificationRegulation', 'replacementIndicator'),
                    information_text: attributes.dig('ModificationRegulation', 'informationText'),
                    approved_flag: attributes.dig('ModificationRegulation', 'approvedFlag'),
                    stopped_flag: attributes.dig('ModificationRegulation', 'stoppedFlag'),
                    effective_end_date: attributes.dig('ModificationRegulation', 'effectiveEndDate'),
                    complete_abrogation_regulation_role: attributes.dig('ModificationRegulation', 'completeAbrogationRegulation', 'regulationRoleType', 'regulationRoleTypeId'),
                    complete_abrogation_regulation_id: attributes.dig('ModificationRegulation', 'completeAbrogationRegulation', 'completeAbrogationRegulationId'),
                    explicit_abrogation_regulation_role: attributes.dig('ModificationRegulation', 'explicitAbrogationRegulation', 'regulationRoleType', 'regulationRoleTypeId'),
                    explicit_abrogation_regulation_id: attributes.dig('ModificationRegulation', 'explicitAbrogationRegulation', 'explicitAbrogationRegulationId'),
                    validity_start_date: attributes.dig('ModificationRegulation', 'validityStartDate'),
                    validity_end_date: attributes.dig('ModificationRegulation', 'validityEndDate'),
                    operation: attributes.dig('ModificationRegulation', 'metainfo', 'opType'),
                    operation_date: attributes.dig('ModificationRegulation', 'metainfo', 'transactionDate'),
                    filename: file,
                  })

      end

      Object.const_get('ModificationRegulation::Operation').multi_insert(regs)
    end
  end
end
