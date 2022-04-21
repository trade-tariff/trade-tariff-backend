TradeTariffBackend::DataMigrator.migration do
  name "Remove national measures of type SPL"

  up do
    applicable {
      Measure::Operation.where("measure_sid < 0").where(measure_type_id: 'SPL').any?
      false
    }
    apply {
      Measure::Operation.where("measure_sid < 0").where(measure_type_id: 'SPL').delete
    }
  end

  down do
    applicable {
      false
    }
    apply {
      # noop
    }
  end
end
