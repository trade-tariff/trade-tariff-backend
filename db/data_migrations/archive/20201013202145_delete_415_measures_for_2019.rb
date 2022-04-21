TradeTariffBackend::DataMigrator.migration do
  name 'End 415 measures created an 2019 for 22042198**'

  MEASURE_TYPE_ID = 'DAE'.freeze # 415
  GOODS_NOMENCLATURE_ITEM_IDS = ["2204219831", "2204219841", "2204219881", "2204219891", "2204219800"]
  VALIDITY_END_DATE = Date.new(2020, 9, 3) # date when issue was reported

  up do
    applicable { false }

    apply do
      Measure::Operation.where(measure_type_id: MEASURE_TYPE_ID, validity_end_date: nil)
                        .where("EXTRACT(year FROM validity_start_date) = 2019")
                        .where(goods_nomenclature_item_id: GOODS_NOMENCLATURE_ITEM_IDS)
                        .each do |mo|
        end_date = Measure::Operation.where(measure_type_id: MEASURE_TYPE_ID)
                                     .where("EXTRACT(year FROM validity_start_date) = 2020")
                                     .where(goods_nomenclature_item_id: mo.goods_nomenclature_item_id)
                                     .last.try(:validity_start_date) || VALIDITY_END_DATE

        mo.validity_end_date = end_date
        mo.save
      end
    end
  end

  down { }
end
