Sequel.migration do
  filename = '20231025075701_quota_critical_fix.rb'

  up do
    if TradeTariffBackend.uk? && QuotaCriticalEvent.where(filename:).none?
      QuotaCriticalEvent.unrestrict_primary_key
      QuotaCriticalEvent.create(
        filename:,
        quota_definition_sid: 23_700,
        occurrence_timestamp: '2023-10-12 00:00:00.000',
        critical_state: 'N',
        critical_state_change_date: '2023-10-12',
        operation: 'C',
        operation_date: Time.zone.today,
      )
      QuotaCriticalEvent.restrict_primary_key
    end
  end

  down do
    if TradeTariffBackend.uk?
      QuotaCriticalEvent.where(filename:).destroy
    end
  end
end
