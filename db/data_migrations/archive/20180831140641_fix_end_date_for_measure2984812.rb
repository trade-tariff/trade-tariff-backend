TradeTariffBackend::DataMigrator.migration do
  name "Set end date for measure sid 2984812 as we have discrepancy in data between the Trade Tariff" \
        "and EU's Taric consultation. See 1703100000."

  MEASURE_SID = 2984812
  VALIDITY_END_DATE = Date.new(2008, 9, 30)

  up do
    applicable { false }
    apply {
      operation = Measure::Operation.where(measure_sid: MEASURE_SID).last
      operation.update(validity_end_date: VALIDITY_END_DATE)
    }
  end

  down do
    applicable { false }
    apply {
      operation = Measure::Operation.where(measure_sid: MEASURE_SID).last
      operation.update(validity_end_date: nil)
    }
  end
end
