TradeTariffBackend::DataMigrator.migration do
  name "Fix National Excise measures with TTY codes 570 and 571"

  up do
    applicable {
      MeasureComponent::Operation.where(
        measure_sid: Measure.where(measure_type_id: ['LEA', 'LGJ']).select(:measure_sid)
      ).where { |o|
       (Sequel.~(measurement_unit_code: 'LTR') | {measurement_unit_code: nil}) | ((Sequel.~(monetary_unit_code: 'GBP')) | { monetary_unit_code: nil })
      }.any?
      false
    }

    apply {
      MeasureComponent::Operation.where(
        measure_sid: Measure.where(measure_type_id: ['LEA', 'LGJ']).select(:measure_sid)
      ).update(
        measurement_unit_code: 'LTR',
        monetary_unit_code: 'GBP'
      )
    }
  end

  down do
    applicable {
      MeasureComponent::Operation.where(
        measure_sid: Measure.where(measure_type_id: ['LEA', 'LGJ']).select(:measure_sid)
      ).where { |o|
       Sequel.expr(measurement_unit_code: 'LTR') | Sequel.expr(monetary_unit_code: 'GBP')
      }.any?
      false
    }

    apply {
      MeasureComponent::Operation.where(
        measure_sid: Measure.where(measure_type_id: ['LEA', 'LGJ']).select(:measure_sid)
      ).update(
        measurement_unit_code: nil,
        monetary_unit_code: nil
      )
    }
  end
end
