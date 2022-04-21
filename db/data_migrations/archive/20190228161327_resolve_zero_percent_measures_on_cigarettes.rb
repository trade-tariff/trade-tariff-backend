TradeTariffBackend::DataMigrator.migration do
  name "Remove new 0% measures cigarette types"

  up do
    applicable do
      Measure::Operation.where(measure_sid: -499434, measure_type_id: 'FAA', goods_nomenclature_item_id: '2402201000').any?
      Measure::Operation.where(measure_sid: -499676, measure_type_id: 'FAA', goods_nomenclature_item_id: '2402201000').any?
      Measure::Operation.where(measure_sid: -513959, measure_type_id: 'FAA', goods_nomenclature_item_id: '2402201000').any?
      Measure::Operation.where(measure_sid: -500832, measure_type_id: 'FAA', goods_nomenclature_item_id: '2402900000').any?
      Measure::Operation.where(measure_sid: -501457, measure_type_id: 'FAA', goods_nomenclature_item_id: '2402900000').any?
      Measure::Operation.where(measure_sid: -512829, measure_type_id: 'FAA', goods_nomenclature_item_id: '2402900000').any?
      false
    end

    apply do
      Measure::Operation.where(measure_sid: -499434, measure_type_id: 'FAA', goods_nomenclature_item_id: '2402201000').delete
      Measure::Operation.where(measure_sid: -499676, measure_type_id: 'FAA', goods_nomenclature_item_id: '2402201000').delete
      Measure::Operation.where(measure_sid: -513959, measure_type_id: 'FAA', goods_nomenclature_item_id: '2402201000').delete
      Measure::Operation.where(measure_sid: -500832, measure_type_id: 'FAA', goods_nomenclature_item_id: '2402900000').delete
      Measure::Operation.where(measure_sid: -501457, measure_type_id: 'FAA', goods_nomenclature_item_id: '2402900000').delete
      Measure::Operation.where(measure_sid: -512829, measure_type_id: 'FAA', goods_nomenclature_item_id: '2402900000').delete
      Measure::Operation.where(measure_sid: -490646).update(validity_end_date: nil)
      Measure::Operation.where(measure_sid: -490647).update(validity_end_date: nil)
    end
  end

  down do
    applicable { false }
    apply {} # noop
  end
end
