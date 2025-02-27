Sequel.migration do
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked
  up do
    if TradeTariffBackend.uk?
      quota_definition = QuotaDefinition.where(
        quota_definition_sid: 22_046,
        filename: 'tariff_dailyExtract_v1_20230109T235959.gzip',
      ).first

      quota_definition.update(initial_volume: 1_471_000.0) if quota_definition

      quota_definition = QuotaDefinition.where(
        quota_definition_sid: 22_052,
        filename: 'tariff_dailyExtract_v1_20230109T235959.gzip',
      ).first

      quota_definition.update(initial_volume: 1_471_000.0) if quota_definition
    end
  end

  down do
    # no down block - these older values were just wrong
  end
end
