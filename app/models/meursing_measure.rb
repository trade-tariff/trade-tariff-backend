class MeursingMeasure < Measure
  set_dataset(
    where(goods_nomenclature_item_id: nil)
      .where(measure_type_id: MeasureType::MEURSING_MEASURES)
      .where(additional_code_type_id: AdditionalCode::MEURSING_TYPE_IDS),
  )
end
