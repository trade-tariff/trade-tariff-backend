module Loaders
  class ProrogationRegulation < Base
    def self.load(file, batch)
      regs = []
      actions = []

      batch.each do |attributes|
        regs.push({
          prorogation_regulation_id: attributes.dig('ProrogationRegulation', 'prorogationRegulationId'),
          prorogation_regulation_role: attributes.dig('ProrogationRegulation', 'regulationRoleType', 'regulationRoleTypeId'),
          published_date: attributes.dig('ProrogationRegulation', 'publishedDate'),
          officialjournal_number: attributes.dig('ProrogationRegulation', 'officialjournalNumber'),
          officialjournal_page: attributes.dig('ProrogationRegulation', 'officialjournalPage'),
          replacement_indicator: attributes.dig('ProrogationRegulation', 'replacementIndicator'),
          information_text: attributes.dig('ProrogationRegulation', 'informationText'),
          approved_flag: attributes.dig('ProrogationRegulation', 'approvedFlag'),
          operation: attributes.dig('ProrogationRegulation', 'metainfo', 'opType'),
          operation_date: attributes.dig('ProrogationRegulation', 'metainfo', 'transactionDate'),
          filename: file,
        })

        action_attributes = if attributes.dig('ProrogationRegulation', 'prorogationRegulationAction').is_a?(Array)
                              attributes.dig('ProrogationRegulation', 'prorogationRegulationAction')
                            else
                              Array.wrap(attributes.dig('ProrogationRegulation', 'prorogationRegulationAction'))
                            end

        action_attributes.each do |action|
          next unless action.is_a?(Hash)

          actions.push({
            prorogation_regulation_id: attributes.dig('ProrogationRegulation', 'prorogationRegulationId'),
            prorogation_regulation_role: attributes.dig('ProrogationRegulation', 'regulationRoleType', 'regulationRoleTypeId'),
            prorogated_regulation_role: action['prorogatedRegulationRole'],
            prorogated_regulation_id: action['prorogatedRegulationId'],
            prorogated_date: action['prorogatedDate'],
            operation: action['metainfo']['opType'],
            operation_date: action['metainfo']['transactionDate'],
            filename: file,
          })
        end
      end

      Object.const_get('ProrogationRegulation::Operation').multi_insert(regs)
      Object.const_get('ProrogationRegulationAction::Operation').multi_insert(actions)
    end
  end
end
