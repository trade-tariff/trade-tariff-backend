TradeTariffBackend::DataMigrator.migration do
  name "Fix CHIEF hectolitre mappings"

  up do
    applicable {
      MeasureComponent::Operation.where(
        measurement_unit_code: 'ASX',
        measurement_unit_qualifier_code: 'X'
      ).any?
      false
    }
    apply {
      MeasureComponent::Operation.where(
        measurement_unit_code: 'ASX',
        measurement_unit_qualifier_code: 'X'
      ).update(
        measurement_unit_code: 'HLT',
        measurement_unit_qualifier_code: nil
      )
    }
  end

  down do
    applicable {
      MeasureComponent::Operation.where(
        measurement_unit_code: 'HLT',
        measurement_unit_qualifier_code: nil
      ).any?
      false
    }
    apply {
      MeasureComponent::Operation.where(
        measurement_unit_code: 'HLT',
        measurement_unit_qualifier_code: nil
      ).update(
        measurement_unit_code: 'ASX',
        measurement_unit_qualifier_code: 'X'
      )
    }
  end
end
