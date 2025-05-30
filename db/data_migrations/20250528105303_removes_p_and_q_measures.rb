P_AND_Q_MEASURE_TYPE_IDS = [
  "305",
  "306",
  "DAA",
  "DAB",
  "DAC",
  "DAE",
  "DAI",
  "DBA",
  "DBB",
  "DBC",
  "DBE",
  "DBI",
  "DCA",
  "DCC",
  "DCE",
  "DCH",
  "DDA",
  "DDB",
  "DDC",
  "DDD",
  "DDE",
  "DDF",
  "DDG",
  "DDJ",
  "DEA",
  "DFA",
  "DFB",
  "DFC",
  "DGC",
  "DHA",
  "DHC",
  "DHE",
  "DHG",
  "EAA",
  "EAE",
  "EBA",
  "EBB",
  "EBE",
  "EBJ",
  "EDA",
  "EDB",
  "EDE",
  "EDJ",
  "EEA",
  "EEF",
  "EFA",
  "EFJ",
  "EGA",
  "EGB",
  "EGJ",
  "EHI",
  "EIA",
  "EIB",
  "EIC",
  "EID",
  "EIE",
  "EIJ",
  "EXA",
  "EXB",
  "EXC",
  "EXD",
  "FAA",
  "FAE",
  "FAI",
  "FBC",
  "FBG",
  "FCC",
  "LAA",
  "LAE",
  "LBA",
  "LBB",
  "LBE",
  "LBJ",
  "LDA",
  "LEA",
  "LEF",
  "LFA",
  "LGJ",
  "VTA",
  "VTE",
  "VTS",
  "VTZ"
].freeze

Sequel.migration do
  up do
    if TradeTariffBackend.xi?
      Measure::Operation.where(measure_type_id: P_AND_Q_MEASURE_TYPE_IDS).delete
      MeasureType::Operation.where(measure_type_id: P_AND_Q_MEASURE_TYPE_IDS).delete
    end
  end

  down do
    # Irreversible!
  end
end
