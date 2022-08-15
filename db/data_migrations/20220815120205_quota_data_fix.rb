Sequel.migration do
  up do
    QuotaCriticalEvent.unrestrict_primary_key
    QuotaDefinition.unrestrict_primary_key

    QuotaCriticalEvent.create(quota_definition_sid: 21_419, occurrence_timestamp: '2022-08-12', critical_state: 'N',
                              critical_state_change_date: '2022-08-12', operation: 'C', operation_date: '2022-08-12')

    QuotaDefinition.create(quota_definition_sid: 21_419, quota_order_number_id: '058020', validity_start_date: '2022-07-01 00:00:00.000', validity_end_date: '2022-09-30 23:59:59.000',
                           quota_order_number_sid: 20_946, volume: 3_536_000.00, initial_volume: 22_635_000.00, measurement_unit_code: 'KGM', maximum_precision: 3,
                           critical_state: 'N', critical_threshold: 90, monetary_unit_code: nil, measurement_unit_qualifier_code: nil,
                           description: nil, operation: 'U', operation_date: '2022-08-12')

    QuotaCriticalEvent.create(quota_definition_sid: 21_917, occurrence_timestamp: '2022-07-12', critical_state: 'N',
                              critical_state_change_date: '2022-07-12', operation: 'C', operation_date: '2022-07-12')

    QuotaDefinition.create(quota_definition_sid: 21_917, quota_order_number_id: '052012', validity_start_date: '2022-01-01 00:00:00.000', validity_end_date: '2022-12-31 00:00:00.000',
                           quota_order_number_sid: 20_805, volume: 17_607_437.52, initial_volume: 13_335_000.00, measurement_unit_code: 'KGM', maximum_precision: 3,
                           critical_state: 'N', critical_threshold: 90, monetary_unit_code: nil, measurement_unit_qualifier_code: nil,
                           description: nil, operation: 'U', operation_date: '2022-07-12')

    QuotaCriticalEvent.create(quota_definition_sid: 21_929, occurrence_timestamp: '2022-07-12', critical_state: 'N',
                              critical_state_change_date: '2022-07-12', operation: 'C', operation_date: '2022-07-12')

    QuotaDefinition.create(quota_definition_sid: 21_929, quota_order_number_id: '052105', validity_start_date: '2022-01-01 00:00:00.000', validity_end_date: '2022-12-31 00:00:00.000',
                           quota_order_number_sid: 20_817, volume: 18_016_449.90, initial_volume: 13_335_000.00, measurement_unit_code: 'KGM', maximum_precision: 3,
                           critical_state: 'N', critical_threshold: 90, monetary_unit_code: nil, measurement_unit_qualifier_code: nil,
                           description: nil, operation: 'U', operation_date: '2022-07-12')

    QuotaCriticalEvent.create(quota_definition_sid: 21_930, occurrence_timestamp: '2022-07-12', critical_state: 'N',
                              critical_state_change_date: '2022-07-12', operation: 'C', operation_date: '2022-07-12')

    QuotaDefinition.create(quota_definition_sid: 21_930, quota_order_number_id: '052106', validity_start_date: '2022-01-01 00:00:00.000', validity_end_date: '2022-12-31 00:00:00.000',
                           quota_order_number_sid: 20_818, volume: 17_425_752.49, initial_volume: 13_335_000.00, measurement_unit_code: 'KGM', maximum_precision: 3,
                           critical_state: 'N', critical_threshold: 90, monetary_unit_code: nil, measurement_unit_qualifier_code: nil,
                           description: nil, operation: 'U', operation_date: '2022-07-12')

    QuotaCriticalEvent.restrict_primary_key
    QuotaDefinition.restrict_primary_key
  end

  down do
    QuotaDefinition.where(quota_definition_sid: 21_419).last.destroy
    QuotaDefinition.where(quota_definition_sid: 21_917).last.destroy
    QuotaDefinition.where(quota_definition_sid: 21_929).last.destroy
    QuotaDefinition.where(quota_definition_sid: 21_930).last.destroy

    QuotaCriticalEvent.where(quota_definition_sid: 21_419).last.destroy
    QuotaCriticalEvent.where(quota_definition_sid: 21_917).last.destroy
    QuotaCriticalEvent.where(quota_definition_sid: 21_929).last.destroy
    QuotaCriticalEvent.where(quota_definition_sid: 21_930).last.destroy
  end
end
