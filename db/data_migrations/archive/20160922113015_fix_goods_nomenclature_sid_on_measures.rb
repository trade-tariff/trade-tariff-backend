TradeTariffBackend::DataMigrator.migration do
  name "Fix reference of goods_nomenclature_sid in the measures table"

  COMMODITY_0305720010 = [-246606, -247410, -245612, -249306, -246513, -247196]
  COMMODITY_0305720020 = [-246601, -246312, -247409, -246494, -246317, -247192, -245614, -249089, -257392 -257549]
  COMMODITY_0305720030 = [-246651, -246314, -247419, -246810, -246326, -247206, -245604, -249088, -257394, -257449]
  COMMODITY_0305790010 = [-246612, -246315, -247411, -246490, -246311, -247189, -245597, -249085, -257411, -257451]
  COMMODITY_0305790020 = [-246598, -246300, -247408, -246826, -246283, -247217, -245598, -249083, -257414, -257555]
  COMMODITY_0305790030 = [-246587, -246305, -247407, -246828, -246280, -247218, -245596, -249082, -257417, -257694]
  COMMODITY_2007993110 = [-267621]
  COMMODITY_2007993190 = [-267622]
  COMMODITY_3823193020 = [-330349, -330350]
  COMMODITY_3823199020 = [-331447, -331446]

  up do
    applicable {
      Measure.filter(measure_sid: COMMODITY_0305720010).any?{|m| m.goods_nomenclature_sid != 97269} ||
      Measure.filter(measure_sid: COMMODITY_0305720020).any?{|m| m.goods_nomenclature_sid != 97270} ||
      Measure.filter(measure_sid: COMMODITY_0305720030).any?{|m| m.goods_nomenclature_sid != 97271} ||
      Measure.filter(measure_sid: COMMODITY_0305790010).any?{|m| m.goods_nomenclature_sid != 97293} ||
      Measure.filter(measure_sid: COMMODITY_0305790020).any?{|m| m.goods_nomenclature_sid != 97294} ||
      Measure.filter(measure_sid: COMMODITY_0305790030).any?{|m| m.goods_nomenclature_sid != 97295} ||
      Measure.filter(measure_sid: COMMODITY_2007993110).any?{|m| m.goods_nomenclature_sid != 33721} ||
      Measure.filter(measure_sid: COMMODITY_2007993190).any?{|m| m.goods_nomenclature_sid != 33722} ||
      Measure.filter(measure_sid: COMMODITY_3823193020).any?{|m| m.goods_nomenclature_sid != 98270} ||
      Measure.filter(measure_sid: COMMODITY_3823199020).any?{|m| m.goods_nomenclature_sid != 98271}
      false
    }

    apply {
      Measure::Operation.filter(measure_sid: COMMODITY_0305720010).update(goods_nomenclature_sid: 97269)
      Measure::Operation.filter(measure_sid: COMMODITY_0305720020).update(goods_nomenclature_sid: 97270)
      Measure::Operation.filter(measure_sid: COMMODITY_0305720030).update(goods_nomenclature_sid: 97271)
      Measure::Operation.filter(measure_sid: COMMODITY_0305790010).update(goods_nomenclature_sid: 97293)
      Measure::Operation.filter(measure_sid: COMMODITY_0305790020).update(goods_nomenclature_sid: 97294)
      Measure::Operation.filter(measure_sid: COMMODITY_0305790030).update(goods_nomenclature_sid: 97295)
      Measure::Operation.filter(measure_sid: COMMODITY_2007993110).update(goods_nomenclature_sid: 33721)
      Measure::Operation.filter(measure_sid: COMMODITY_2007993190).update(goods_nomenclature_sid: 33722)
      Measure::Operation.filter(measure_sid: COMMODITY_3823193020).update(goods_nomenclature_sid: 98270)
      Measure::Operation.filter(measure_sid: COMMODITY_3823199020).update(goods_nomenclature_sid: 98271)
    }
  end

  down do
    applicable {
      Measure.filter(measure_sid: COMMODITY_0305720010).any?{|m| m.goods_nomenclature_sid != 96187} ||
      Measure.filter(measure_sid: COMMODITY_0305720020).any?{|m| m.goods_nomenclature_sid != 96188} ||
      Measure.filter(measure_sid: COMMODITY_0305720030).any?{|m| m.goods_nomenclature_sid != 96197} ||
      Measure.filter(measure_sid: COMMODITY_0305790010).any?{|m| m.goods_nomenclature_sid != 96192} ||
      Measure.filter(measure_sid: COMMODITY_0305790020).any?{|m| m.goods_nomenclature_sid != 96193} ||
      Measure.filter(measure_sid: COMMODITY_0305790030).any?{|m| m.goods_nomenclature_sid != 96199} ||
      Measure.filter(measure_sid: COMMODITY_2007993110).any?{|m| m.goods_nomenclature_sid != 97067} ||
      Measure.filter(measure_sid: COMMODITY_2007993190).any?{|m| m.goods_nomenclature_sid != 97061} ||
      Measure.filter(measure_sid: COMMODITY_3823193020).any?{|m| m.goods_nomenclature_sid != 98114} ||
      Measure.filter(measure_sid: COMMODITY_3823199020).any?{|m| m.goods_nomenclature_sid != 98115}
      false
    }

    apply {
      Measure::Operation.filter(measure_sid: COMMODITY_0305720010).update(goods_nomenclature_sid: 96187)
      Measure::Operation.filter(measure_sid: COMMODITY_0305720020).update(goods_nomenclature_sid: 96188)
      Measure::Operation.filter(measure_sid: COMMODITY_0305720030).update(goods_nomenclature_sid: 96197)
      Measure::Operation.filter(measure_sid: COMMODITY_0305790010).update(goods_nomenclature_sid: 96192)
      Measure::Operation.filter(measure_sid: COMMODITY_0305790020).update(goods_nomenclature_sid: 96193)
      Measure::Operation.filter(measure_sid: COMMODITY_0305790030).update(goods_nomenclature_sid: 96199)
      Measure::Operation.filter(measure_sid: COMMODITY_2007993110).update(goods_nomenclature_sid: 97067)
      Measure::Operation.filter(measure_sid: COMMODITY_2007993190).update(goods_nomenclature_sid: 97061)
      Measure::Operation.filter(measure_sid: COMMODITY_3823193020).update(goods_nomenclature_sid: 98114)
      Measure::Operation.filter(measure_sid: COMMODITY_3823199020).update(goods_nomenclature_sid: 98115)
    }
  end
end
