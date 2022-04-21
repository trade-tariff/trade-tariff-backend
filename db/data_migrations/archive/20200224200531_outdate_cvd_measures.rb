TradeTariffBackend::DataMigrator.migration do
  name "Set validity end date for CVD (CVED) measures"

  MEASURE_TYPE_ID = "CVD"
  VALIDITY_END_DATE = Time.parse("2020-02-29 23:59:59")

  up do
    applicable {
      Measure::Operation.where(measure_type_id: MEASURE_TYPE_ID, validity_end_date: nil).any?
      false
    }

    apply {
      Measure::Operation.where(measure_type_id: MEASURE_TYPE_ID, validity_end_date: nil).update(validity_end_date: VALIDITY_END_DATE)
    }
  end

  down do
    applicable {
      Measure::Operation.where(measure_type_id: MEASURE_TYPE_ID, validity_end_date: VALIDITY_END_DATE).any?
      false
    }
    apply {
      Measure::Operation.where(measure_type_id: MEASURE_TYPE_ID, validity_end_date: VALIDITY_END_DATE).update(validity_end_date: nil)
    }
  end
end
