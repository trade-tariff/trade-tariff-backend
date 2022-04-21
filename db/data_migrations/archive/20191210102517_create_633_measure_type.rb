# data/chief/2019-11-01_KBT009(19305).txt:"MFCM       ","31/10/2019:09:39:00","I","EX","EXF","633",null,null,null,"31/10/2019:09:37:00","24039990 00","N","Y","N",
# data/chief/2019-12-02_KBT009(19336).txt:"MFCM       ","01/12/2019:00:00:00","U","EX","EXF","633",null,null,null,"28/11/2019:16:55:00","24039990 00","N","Y","N",

TradeTariffBackend::DataMigrator.migration do
  name 'Create 633 national measure type with description AND fix 487 measure type'

  up do
    applicable do
      MeasureType::Operation.where(measure_type_id: 'FCC').none?
      false
    end

    apply do
      Measure::Operation.unrestrict_primary_key
      MeasureType::Operation.unrestrict_primary_key
      MeasureTypeDescription::Operation.unrestrict_primary_key

      # Update 487 measure_type_id for MeasureType and MeasureTypeDescription
      MeasureType::Operation.where(measure_type_id: 'EXF').update(measure_type_id: 'DHG', measure_type_acronym: 'DHG')
      MeasureTypeDescription::Operation.where(measure_type_id: 'EXF').update(measure_type_id: 'DHG')
      # Keep it only for: 2206008100, 2206003100, 2206005100
      Measure::Operation.where(measure_type_id: 'EXF', goods_nomenclature_item_id: %w(2206008100 2206003100 2206005100)).update(measure_type_id: 'DHG')

      # Create 633 measure type
      MeasureType::Operation.create(
        measure_type_id: 'FCC',
        validity_start_date: Date.new(2019, 10, 31),
        validity_end_date: nil,
        trade_movement_code: 0,
        priority_code: 5,
        measure_component_applicable_code: '0',
        measure_type_acronym: 'FCC',
        origin_dest_code: 0,
        order_number_capture_code: 2,
        measure_explosion_level: 20,
        measure_type_series_id: 'Q',
        national: true,
        operation: 'C',
        operation_date: nil
      )
      # Create description for 633 measure type
      MeasureTypeDescription::Operation.create(
        measure_type_id: 'FCC',
        language_id: 'EN',
        description: 'EXCISE - FULL, 633, TOBACCO FOR HEATING',
        national: true,
        operation: 'C'
      )
      # Update 487 measure_type_id for some Measures
      Measure::Operation.where(measure_type_id: 'EXF', goods_nomenclature_item_id: %w(8543707000 2403999000)).update(measure_type_id: 'FCC')
    end
  end

  down do

  end
end
