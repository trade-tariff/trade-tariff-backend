Sequel.migration do
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked
  up do
    next unless TradeTariffBackend.uk?

    Sequel::Model.db.run <<~SQL
      DELETE FROM geographical_area_memberships_oplog gamo
      WHERE
	      filename IN ('tariff_dailyExtract_v1_20220622T235959.gzip', 'tariff_dailyExtract_v1_20220721T235959.gzip')
	      AND oid NOT IN (
		      SELECT max(latest.oid) AS max
          FROM uk.geographical_area_memberships_oplog latest
          WHERE
            gamo.geographical_area_sid = latest.geographical_area_sid AND
            gamo.geographical_area_group_sid = latest.geographical_area_group_sid AND
            gamo.validity_start_date = latest.validity_start_date AND
            gamo.filename = latest.filename
	      )
    SQL
  end

  down do
    # Not reversible
  end
end
