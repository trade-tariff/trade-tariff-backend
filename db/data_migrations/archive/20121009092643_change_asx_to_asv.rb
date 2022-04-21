TradeTariffBackend::DataMigrator.migration do
  name "Convert MeasurementUnit code from ASX to ASV"

  up do
    applicable {
      MeasureComponent::Operation.where(measurement_unit_code: 'ASX').any?
      false
    }
    apply {
      MeasureComponent::Operation.where(measurement_unit_code: 'ASX').update(measurement_unit_code: 'ASV')
    }
  end

  down do
    applicable {
      MeasureComponent::Operation.where(measurement_unit_code: 'ASV').any?
      false
    }
    apply {
      MeasureComponent::Operation.where(measurement_unit_code: 'ASV').update(measurement_unit_code: 'ASX')
    }
  end
end
