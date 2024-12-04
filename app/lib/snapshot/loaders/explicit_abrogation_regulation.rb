module Loaders
  class ExplicitAbrogationRegulation < Base
    def self.load(file, batch)
      regs = []

      batch.each do |attributes|
        regs.push({
                    explicit_abrogation_regulation_role: attributes.dig('ExplicitAbrogationRegulation', 'regulationRoleType', 'regulationRoleTypeId'),
                    explicit_abrogation_regulation_id: attributes.dig('ExplicitAbrogationRegulation', 'explicitAbrogationRegulationId'),
                    published_date: attributes.dig('ExplicitAbrogationRegulation', 'publishedDate'),
                    officialjournal_number: attributes.dig('ExplicitAbrogationRegulation', 'officialjournalNumber'),
                    officialjournal_page: attributes.dig('ExplicitAbrogationRegulation', 'officialjournalPage'),
                    replacement_indicator: attributes.dig('ExplicitAbrogationRegulation', 'replacementIndicator'),
                    abrogation_date: attributes.dig('ExplicitAbrogationRegulation', 'abrogationDate'),
                    information_text: attributes.dig('ExplicitAbrogationRegulation', 'informationText'),
                    approved_flag: attributes.dig('ExplicitAbrogationRegulation', 'approvedFlag'),
                    operation: attributes.dig('ExplicitAbrogationRegulation', 'metainfo', 'opType'),
                    operation_date: attributes.dig('ExplicitAbrogationRegulation', 'metainfo', 'transactionDate'),
                    filename: file,
                  })

      end

      Object.const_get('ExplicitAbrogationRegulation::Operation').multi_insert(regs)
    end
  end
end
