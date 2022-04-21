TradeTariffBackend::DataMigrator.migration do
  name "Fix Missing measure types descriptions"

  up do
    applicable { true }
    # The apply block is idempotent
    apply {

      MeasureTypeDescription.unrestrict_primary_key
      MeasureTypeDescription.find_or_create(measure_type_id: "DBE",
                                            language_id: "EN",
                                            description: "EXCISE - FULL, 425, MADE-WINE OF BETWEEN 15%-22% VOL",
                                            national: true,
                                            operation: "U")

      MeasureTypeDescription.find_or_create(measure_type_id: "AIL",
                                            language_id: "EN",
                                            description: "Health and Safety Executive Import Licensing Firearms and Ammunition",
                                            national: true,
                                            operation: "U")

      MeasureTypeDescription.find_or_create(measure_type_id: "DCC",
                                            language_id: "EN",
                                            description: "EXCISE - FULL, 433, WINE, MADE-WINE EXC 1.2% VOL NOT EXC 4% VOL.",
                                            national: true,
                                            operation: "U")

      MeasureTypeDescription.find_or_create(measure_type_id: "DCE",
                                            language_id: "EN",
                                            description: "EXCISE - FULL, 435, WINE, MADE-WINE EXC 4% VOL NOT EXC 5.5% VOL.",
                                            national: true,
                                            operation: "U")
    }
  end

  down do
    applicable { false }
    apply { } # noop
  end
end
