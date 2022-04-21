TradeTariffBackend::DataMigrator.migration do
  name "Remove 0% measures on further cigarette types"

  up do
    applicable {
      Measure::Operation.where(measure_sid: -491538).where(measure_type_id: 'FAA').where(goods_nomenclature_item_id: '2402900000').any?
      Measure::Operation.where(measure_sid: -491539).where(measure_type_id: 'FAA').where(goods_nomenclature_item_id: '2402201000').any?
      false
    }

    apply {
      Measure::Operation.where(measure_sid: -491538).where(measure_type_id: 'FAA').where(goods_nomenclature_item_id: '2402900000').delete
      Measure::Operation.where(measure_sid: -491539).where(measure_type_id: 'FAA').where(goods_nomenclature_item_id: '2402201000').delete
      Measure::Operation.where(measure_sid: -490646).update(validity_end_date: nil)
      Measure::Operation.where(measure_sid: -490647).update(validity_end_date: nil)
    }
  end

  down do
    applicable { false }
    apply {} # noop
  end
end
