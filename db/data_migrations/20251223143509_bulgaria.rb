Sequel.migration do
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked
  up do
    bulgaria = ExchangeRateCountryCurrency.find(
      country_code:         "BG",
    )
    bulgaria.validity_end_date = Date.parse("2026-01-31")
    bulgaria.save
  end

  down do
    bulgaria = ExchangeRateCountryCurrency.find(
      country_code:         "BG",
    )
    bulgaria.validity_end_date = nil
    bulgaria.save
  end
end
