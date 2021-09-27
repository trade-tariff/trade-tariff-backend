class MeursingMeasure < Measure
  initial_dataset = where(goods_nomenclature_item_id: nil).where(measure_type_id: MeasureType::MEURSING_MEASURES).where(additional_code_type_id: AdditionalCode::MEURSING_TYPE_IDS)

  set_dataset(initial_dataset, inherited: true)

  set_primary_key :measure_sid

  # End dates of meursing measures come from Measure#generating_regulation#validity_end_date so we
  # need to extend the TimeMachine functionality and filter in current meursing measures. See Measure#validity_end_date override
  def current?
    validity_end_date.blank? || validity_end_date >= point_in_time
  end
end
