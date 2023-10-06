Sequel.migration do
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked
  up do
    ExchangeRateCurrencyRate.by_type('spot').each do |rate|
      rate.validity_end_date = rate.validity_start_date
      rate.save
    end
  end

  down do
    ExchangeRateCurrencyRate.by_type('spot').each do |rate|
      rate.validity_end_date = nil
      rate.save
    end
  end
end
