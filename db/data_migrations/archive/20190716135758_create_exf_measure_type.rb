=begin
CHIEF transformer do not handle TAMT (measure type) and RVTT (measure type description)
record types, so we created these records manually.

2019-01-10_KBT009(19010).txt:2
"TAMT       ","09/01/2019:10:37:00","I","487","EX","EXF",null,null,"09/01/2019:10:36:00",

2018-12-28_KBT009(18362).txt:4987
"RVTT       ","27/12/2018:10:27:00","I","487",null,null,"27/12/2018:10:25:00",null,"N",null,null,"4","N","Y","CIDER AND PERRY EXCEEDING 6.9% - NOT EXCEEDING 7.5% ABV","Y","Y","E",
=end


# !Note - this migration is not completely correct
# Instead of EXF we should use DHG code (487)
# This will be fixed in data migration on 10.12.2019
TradeTariffBackend::DataMigrator.migration do
  name 'Create EXF national measure type with description'

  up do
    applicable do
      MeasureType.where(measure_type_id: 'EXF').blank?
      false
    end

    apply do
      MeasureType.unrestrict_primary_key
      MeasureType.create(measure_type_id: 'EXF',
                         validity_start_date: Date.new(2019, 1, 9),
                         validity_end_date: nil,
                         trade_movement_code: 0,
                         priority_code: 5,
                         measure_component_applicable_code: '0',
                         measure_type_acronym: 'EXF',
                         origin_dest_code: 0,
                         order_number_capture_code: 2,
                         measure_explosion_level: 20,
                         measure_type_series_id: 'Q',
                         national: true,
                         operation: 'C',
                         operation_date: nil)

      MeasureTypeDescription.unrestrict_primary_key
      MeasureTypeDescription.create(measure_type_id: 'EXF',
                                    language_id: 'EN',
                                    description: 'EXCISE - FULL, 487, CIDER AND PERRY EXCEEDING 6.9% - NOT EXCEEDING 7.5% ABV',
                                    national: true,
                                    operation: 'C')
    end
  end

  down do
    # applicable {
    #   MeasureType.where(measure_type_id: 'EXF').present?
    # }
    # apply {
    #   MeasureTypeDescription.where(measure_type_id: 'EXF').map(&:destroy)
    #   MeasureType.where(measure_type_id: 'EXF').map(&:destroy)
    # }
  end
end
