TradeTariffBackend::DataMigrator.migration do
  name 'Delete 571, 572 and 589 measures for commodities: 1516209830 and 1516209829. Source: chief_meas.csv'

  MEASURE_TYPES = %w(EGA EGB EHI)
  COMMODITIES = %w(1516209800)

  up do
    applicable { false }

    apply do
      Measure::Operation.where(measure_type_id: MEASURE_TYPES, goods_nomenclature_item_id: COMMODITIES).delete
    end
  end

  down { }
end
