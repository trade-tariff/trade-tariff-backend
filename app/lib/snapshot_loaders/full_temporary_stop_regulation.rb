module SnapshotLoaders
  class FullTemporaryStopRegulation < Base
    def self.load(file, batch)
      regs = []
      actions = []

      batch.each do |attributes|
        regs.push({
          full_temporary_stop_regulation_id: attributes.dig('FullTemporaryStopRegulation', 'fullTemporaryStopRegulationId'),
          full_temporary_stop_regulation_role: attributes.dig('FullTemporaryStopRegulation', 'regulationRoleType', 'regulationRoleTypeId'),
          published_date: attributes.dig('FullTemporaryStopRegulation', 'publishedDate'),
          officialjournal_number: attributes.dig('FullTemporaryStopRegulation', 'officialjournalNumber'),
          officialjournal_page: attributes.dig('FullTemporaryStopRegulation', 'officialjournalPage'),
          effective_enddate: attributes.dig('FullTemporaryStopRegulation', 'effectiveEndDate'),
          explicit_abrogation_regulation_role: attributes.dig('FullTemporaryStopRegulation', 'explicitAbrogationRegulation', 'regulationRoleType', 'regulationRoleTypeId'),
          explicit_abrogation_regulation_id: attributes.dig('FullTemporaryStopRegulation', 'explicitAbrogationRegulation', 'explicitAbrogationRegulationId'),
          replacement_indicator: attributes.dig('FullTemporaryStopRegulation', 'replacementIndicator'),
          information_text: attributes.dig('FullTemporaryStopRegulation', 'informationText'),
          approved_flag: attributes.dig('FullTemporaryStopRegulation', 'approvedFlag'),
          operation: attributes.dig('FullTemporaryStopRegulation', 'metainfo', 'opType'),
          operation_date: attributes.dig('FullTemporaryStopRegulation', 'metainfo', 'transactionDate'),
          filename: file,
        })

        action_attributes = if attributes.dig('FullTemporaryStopRegulation', 'ftsRegulationAction').is_a?(Array)
                              attributes.dig('FullTemporaryStopRegulation', 'ftsRegulationAction')
                            else
                              Array.wrap(attributes.dig('FullTemporaryStopRegulation', 'ftsRegulationAction'))
                            end

        action_attributes.each do |action|
          next unless action.is_a?(Hash)

          actions.push({
            fts_regulation_id: attributes.dig('FullTemporaryStopRegulation', 'fullTemporaryStopRegulationId'),
            fts_regulation_role: attributes.dig('FullTemporaryStopRegulation', 'regulationRoleType', 'regulationRoleTypeId'),
            stopped_regulation_role: action['stoppedRegulationRole'],
            stopped_regulation_id: action['stoppedRegulationId'],
            operation: action.dig('metainfo', 'opType'),
            operation_date: action.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end
      end

      Object.const_get('FtsRegulationAction::Operation').multi_insert(actions)
      Object.const_get('FullTemporaryStopRegulation::Operation').multi_insert(regs)
    end
  end
end
