module Loaders
  class QuotaDefinition < Base
    def self.load(file, batch)
      definitions = []
      balance_events = []
      associations = []
      blocking_periods = []
      critical_events = []
      exhaustion_events = []
      reopening_events = []
      sus_periods = []
      unsuspension_events = []
      unblocking_events = []
      transferred_events = []

      batch.each do |attributes|
        definitions.push({
          quota_definition_sid: attributes.dig('QuotaDefinition', 'sid'),
          quota_order_number_sid: attributes.dig('QuotaDefinition', 'quotaOrderNumber', 'sid'),
          quota_order_number_id: attributes.dig('QuotaDefinition', 'quotaOrderNumber', 'quotaOrderNumberId'),
          volume: attributes.dig('QuotaDefinition', 'volume'),
          initial_volume: attributes.dig('QuotaDefinition', 'initialVolume'),
          maximum_precision: attributes.dig('QuotaDefinition', 'maximumPrecision'),
          critical_state: attributes.dig('QuotaDefinition', 'criticalState'),
          critical_threshold: attributes.dig('QuotaDefinition', 'criticalThreshold'),
          monetary_unit_code: attributes.dig('QuotaDefinition', 'monetaryUnit', 'monetaryUnitCode'),
          measurement_unit_code: attributes.dig('QuotaDefinition', 'measurementUnit', 'measurementUnitCode'),
          measurement_unit_qualifier_code: attributes.dig('QuotaDefinition', 'measurementUnitQualifier', 'measurementUnitQualifierCode'),
          description: attributes.dig('QuotaDefinition', 'description'),
          validity_start_date: attributes.dig('QuotaDefinition', 'validityStartDate'),
          validity_end_date: attributes.dig('QuotaDefinition', 'validityEndDate'),
          operation: attributes.dig('QuotaDefinition', 'metainfo', 'opType'),
          operation_date: attributes.dig('QuotaDefinition', 'metainfo', 'transactionDate'),
          filename: file,
        })

        balance_attributes = if attributes.dig('QuotaDefinition', 'quotaBalanceEvent').is_a?(Array)
                               attributes.dig('QuotaDefinition', 'quotaBalanceEvent')
                             else
                               Array.wrap(attributes.dig('QuotaDefinition', 'quotaBalanceEvent'))
                             end

        balance_attributes.each do |balance|
          next unless balance.is_a?(Hash)

          balance_events.push({
            quota_definition_sid: attributes.dig('QuotaDefinition', 'sid'),
            occurrence_timestamp: balance['meursingHeadingNumber'],
            last_import_date_in_allocation: balance['rowColumnCode'],
            old_balance: balance['rowColumnCode'],
            new_balance: balance['rowColumnCode'],
            imported_amount: balance['rowColumnCode'],
            operation: balance.dig('metainfo', 'opType'),
            operation_date: balance.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end

        association_attributes = if attributes.dig('QuotaDefinition', 'quotaAssociation').is_a?(Array)
                                   attributes.dig('QuotaDefinition', 'quotaAssociation')
                                 else
                                   Array.wrap(attributes.dig('QuotaDefinition', 'quotaAssociation'))
                                 end

        association_attributes.each do |association|
          next unless association.is_a?(Hash)

          associations.push({
            main_quota_definition_sid: attributes.dig('QuotaDefinition', 'sid'),
            sub_quota_definition_sid: association.dig('subQuotaDefinition', 'sid'),
            relation_type: association['relationType'],
            coefficient: association['coefficient'],
            operation: association.dig('metainfo', 'opType'),
            operation_date: association.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end

        period_attributes = if attributes.dig('QuotaDefinition', 'quotaBlockingPeriod').is_a?(Array)
                              attributes.dig('QuotaDefinition', 'quotaBlockingPeriod')
                            else
                              Array.wrap(attributes.dig('QuotaDefinition', 'quotaBlockingPeriod'))
                            end

        period_attributes.each do |period|
          next unless period.is_a?(Hash)

          blocking_periods.push({
            quota_definition_sid: attributes.dig('QuotaDefinition', 'sid'),
            quota_blocking_period_sid: period['quotaBlockingPeriodSid'],
            blocking_start_date: period['blockingStartDate'],
            blocking_end_date: period['blockingEndDate'],
            blocking_period_type: period['blockingPeriodType'],
            description: period['description'],
            operation: period.dig('metainfo', 'opType'),
            operation_date: period.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end

        critical_event_attributes = if attributes.dig('QuotaDefinition', 'quotaCriticalEvent').is_a?(Array)
                                      attributes.dig('QuotaDefinition', 'quotaCriticalEvent')
                                    else
                                      Array.wrap(attributes.dig('QuotaDefinition', 'quotaCriticalEvent'))
                                    end

        critical_event_attributes.each do |event|
          next unless event.is_a?(Hash)

          critical_events.push({
            quota_definition_sid: attributes.dig('QuotaDefinition', 'sid'),
            occurrence_timestamp: event['occurrenceTimestamp'],
            critical_state: event['criticalState'],
            critical_state_change_date: event['criticalStateChangeDate'],
            operation: event.dig('metainfo', 'opType'),
            operation_date: event.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end

        exhaustion_event_attributes = if attributes.dig('QuotaDefinition', 'quotaExhaustionEvent').is_a?(Array)
                                        attributes.dig('QuotaDefinition', 'quotaExhaustionEvent')
                                      else
                                        Array.wrap(attributes.dig('QuotaDefinition', 'quotaExhaustionEvent'))
                                      end

        exhaustion_event_attributes.each do |event|
          next unless event.is_a?(Hash)

          exhaustion_events.push({
            quota_definition_sid: attributes.dig('QuotaDefinition', 'sid'),
            occurrence_timestamp: event['occurrenceTimestamp'],
            exhaustion_date: event['exhaustionDate'],
            operation: event.dig('metainfo', 'opType'),
            operation_date: event.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end

        reopening_event_attributes = if attributes.dig('QuotaDefinition', 'quotaReopeningEvent').is_a?(Array)
                                       attributes.dig('QuotaDefinition', 'quotaReopeningEvent')
                                     else
                                       Array.wrap(attributes.dig('QuotaDefinition', 'quotaReopeningEvent'))
                                     end

        reopening_event_attributes.each do |event|
          next unless event.is_a?(Hash)

          reopening_events.push({
            quota_definition_sid: attributes.dig('QuotaDefinition', 'sid'),
            occurrence_timestamp: event['occurrenceTimestamp'],
            reopening_date: event['reopeningDate'],
            operation: event.dig('metainfo', 'opType'),
            operation_date: event.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end

        sus_period_attributes = if attributes.dig('QuotaDefinition', 'quotaSuspensionPeriod').is_a?(Array)
                                  attributes.dig('QuotaDefinition', 'quotaSuspensionPeriod')
                                else
                                  Array.wrap(attributes.dig('QuotaDefinition', 'quotaSuspensionPeriod'))
                                end

        sus_period_attributes.each do |period|
          next unless period.is_a?(Hash)

          sus_periods.push({
            quota_definition_sid: attributes.dig('QuotaDefinition', 'sid'),
            quota_suspension_period_sid: period['sid'],
            suspension_start_date: period['suspensionStartDate'],
            suspension_end_date: period['suspensionEndDate'],
            description: period['description'],
            operation: period.dig('metainfo', 'opType'),
            operation_date: period.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end

        unsuspension_event_attributes = if attributes.dig('QuotaDefinition', 'quotaUnsuspensionEvent').is_a?(Array)
                                          attributes.dig('QuotaDefinition', 'quotaUnsuspensionEvent')
                                        else
                                          Array.wrap(attributes.dig('QuotaDefinition', 'quotaUnsuspensionEvent'))
                                        end

        unsuspension_event_attributes.each do |event|
          next unless event.is_a?(Hash)

          unsuspension_events.push({
            quota_definition_sid: attributes.dig('QuotaDefinition', 'sid'),
            occurrence_timestamp: event['occurrenceTimestamp'],
            unsuspension_date: event['unsuspensionDate'],
            operation: event.dig('metainfo', 'opType'),
            operation_date: event.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end

        unblocking_event_attributes = if attributes.dig('QuotaDefinition', 'quotaUnblockingEvent').is_a?(Array)
                                        attributes.dig('QuotaDefinition', 'quotaUnblockingEvent')
                                      else
                                        Array.wrap(attributes.dig('QuotaDefinition', 'quotaUnblockingEvent'))
                                      end

        unblocking_event_attributes.each do |event|
          next unless event.is_a?(Hash)

          unblocking_events.push({
            quota_definition_sid: attributes.dig('QuotaDefinition', 'sid'),
            occurrence_timestamp: event['occurrenceTimestamp'],
            unblocking_date: event['unblockingDate'],
            operation: event.dig('metainfo', 'opType'),
            operation_date: event.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end

        transferred_event_attributes = if attributes.dig('QuotaDefinition', 'quotaClosedAndTransferredEvent').is_a?(Array)
                                         attributes.dig('QuotaDefinition', 'quotaClosedAndTransferredEvent')
                                       else
                                         Array.wrap(attributes.dig('QuotaDefinition', 'quotaClosedAndTransferredEvent'))
                                       end

        transferred_event_attributes.each do |event|
          next unless event.is_a?(Hash)

          transferred_events.push({
            quota_definition_sid: attributes.dig('QuotaDefinition', 'sid'),
            occurrence_timestamp: event['occurrenceTimestamp'],
            closing_date: event['closingDate'],
            target_quota_definition_sid: event.dig('targetQuotaDefinition', 'sid'),
            transferred_amount: event['transferredAmount'],
            operation: event.dig('metainfo', 'opType'),
            operation_date: event.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end
      end

      Object.const_get('QuotaDefinition::Operation').multi_insert(definitions)
      Object.const_get('QuotaBalanceEvent::Operation').multi_insert(balance_events)
      Object.const_get('QuotaAssociation::Operation').multi_insert(associations)
      Object.const_get('QuotaBlockingPeriod::Operation').multi_insert(blocking_periods)
      Object.const_get('QuotaCriticalEvent::Operation').multi_insert(critical_events)
      Object.const_get('QuotaExhaustionEvent::Operation').multi_insert(exhaustion_events)
      Object.const_get('QuotaReopeningEvent::Operation').multi_insert(reopening_events)
      Object.const_get('QuotaSuspensionPeriod::Operation').multi_insert(sus_periods)
      Object.const_get('QuotaUnsuspensionEvent::Operation').multi_insert(unsuspension_events)
      Object.const_get('QuotaUnblockingEvent::Operation').multi_insert(unblocking_events)
      Object.const_get('QuotaClosedAndTransferredEvent::Operation').multi_insert(transferred_events)
    end
  end
end
