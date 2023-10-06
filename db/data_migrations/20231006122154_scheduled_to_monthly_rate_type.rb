Sequel.migration do
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked
  up do
    ExchangeRateCurrencyRate.by_type('scheduled').each do |rate|
      rate.rate_type = 'monthly'
      rate.save
    end
  end

  down do
    ExchangeRateCurrencyRate.by_type('monthly').each do |rate|
      rate.rate_type = 'scheduled'
      rate.save
    end
  end
end
