TradeTariffBackend::DataMigrator.migration do
  name "Remove 0% measure on Cigarettes Other"

  up do
    applicable {
      Measure::Operation.where(measure_sid: -491537).where(measure_type_id: 'FAA').where(goods_nomenclature_item_id: '2402209000').any?
      false
    }
    apply {
      Measure::Operation.where(measure_sid: -491537).where(measure_type_id: 'FAA').where(goods_nomenclature_item_id: '2402209000').delete
      Measure::Operation.where(measure_sid: -490645).update(validity_end_date: nil)
    }
  end

  down do
    applicable { false }
    apply { } # noop
  end
end
