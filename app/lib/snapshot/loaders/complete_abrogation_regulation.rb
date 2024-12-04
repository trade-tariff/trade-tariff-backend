module Loaders
  class CompleteAbrogationRegulation < Base
    def self.load(file, batch)
      regs = []

      batch.each do |attributes|
        regs.push({
                    complete_abrogation_regulation_role: attributes.dig('CompleteAbrogationRegulation', 'regulationRoleType', 'regulationRoleTypeId'),
                    complete_abrogation_regulation_id: attributes.dig('CompleteAbrogationRegulation', 'completeAbrogationRegulationId'),
                    published_date: attributes.dig('CompleteAbrogationRegulation', 'publishedDate'),
                    officialjournal_number: attributes.dig('CompleteAbrogationRegulation', 'officialjournalNumber'),
                    officialjournal_page: attributes.dig('CompleteAbrogationRegulation', 'officialjournalPage'),
                    replacement_indicator: attributes.dig('CompleteAbrogationRegulation', 'replacementIndicator'),
                    information_text: attributes.dig('CompleteAbrogationRegulation', 'informationText'),
                    approved_flag: attributes.dig('CompleteAbrogationRegulation', 'approvedFlag'),
                    operation: attributes.dig('CompleteAbrogationRegulation', 'metainfo', 'opType'),
                    operation_date: attributes.dig('CompleteAbrogationRegulation', 'metainfo', 'transactionDate'),
                    filename: file,
                  })

      end

      Object.const_get('CompleteAbrogationRegulation::Operation').multi_insert(regs)
    end
  end
end
