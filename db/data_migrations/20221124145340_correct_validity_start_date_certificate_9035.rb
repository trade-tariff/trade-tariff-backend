Sequel.migration do
  # IMPORTANT! Data migrations should be Idempotent, they may get re-run as part
  # of data rollbacks

  up do
    if TradeTariffBackend.uk?
      Sequel::Model.db[:certificate_description_periods_oplog]
        .where(certificate_description_period_sid: 5167, validity_start_date: '2023-11-23 00:00:00')
        .update(validity_start_date: '2022-11-23 00:00:00')
    end
  end

  down do
    if TradeTariffBackend.uk?
      Sequel::Model.db[:certificate_description_periods_oplog]
        .where(certificate_description_period_sid: 5167, validity_start_date: '2022-11-23 00:00:00')
        .update(validity_start_date: '2023-11-23 00:00:00')
    end
  end
end
