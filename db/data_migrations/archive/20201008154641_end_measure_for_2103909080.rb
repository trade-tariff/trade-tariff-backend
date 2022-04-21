TradeTariffBackend::DataMigrator.migration do
  name 'End measure 425 for commodity 2103909080.'

  MEASURE_TYPE = 'DBE'
  COMMODITY = '2103909080'

  up do
    applicable { false }

    apply do
      Measure::Operation.where(
        measure_type_id: MEASURE_TYPE, 
        goods_nomenclature_item_id: COMMODITY
      ).each do |measure|
        measure.validity_end_date = measure.validity_end_date || '2020-02-29 00:00:00'
        # only update the measures where the validity_end_date is nil, otherwise, assume there's a date there for a reason
        measure.save
      end
    end
  end

  down do
    applicable { true }

    apply do
      Measure::Operation.where(
        measure_type_id: MEASURE_TYPE, 
        goods_nomenclature_item_id: COMMODITY,
        validity_end_date: '2020-02-29 00:00:00'
      ).each do |measure|
        measure.validity_end_date = nil
        measure.save
      end
    end
  end
end
