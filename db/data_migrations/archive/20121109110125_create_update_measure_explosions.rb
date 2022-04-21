TradeTariffBackend::DataMigrator.migration do
  name "Keep national MeasureType explosion level high"
  desc "This allows to pass conformance validations on Measure"

  up do
    applicable {
      MeasureType::Operation.where(national: true)
        .where(Sequel.~(measure_explosion_level: 20)).any?
      false
    }
    apply {
      MeasureType::Operation.where(national: true).update(measure_explosion_level: 20)
    }
  end

  down do
    applicable {
      MeasureType::Operation.where(national: true)
        .where(Sequel.~(measure_explosion_level: 2)).any?
      false
    }

    apply {
      MeasureType::Operation.where(national: true).update(measure_explosion_level: 2)
    }
  end
end
