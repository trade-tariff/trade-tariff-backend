# encoding: utf-8
TradeTariffBackend::DataMigrator.migration do
  name "Add default measurement unit abbreviations"

  up do
    applicable {
      MeasurementUnitAbbreviation.empty?
      false
    }

    apply {
      [ {abbr: "% vol",                code: "ASV"},
        {abbr: "% vol/hl",             code: "ASV", qualifier: "X"},
        {abbr: "ct/l",                 code: "CCT"},
        {abbr: "100 p/st",             code: "CEN"},
        {abbr: "c/k",                  code: "CTM"},
        {abbr: "10 000 kg/polar",      code: "DAP"},
        {abbr: "kg DHS",               code: "DHS"},
        {abbr: "100 kg",               code: "DTN"},
        {abbr: "100 kg/net eda",       code: "DTN", qualifier: "E"},
        {abbr: "100 kg common wheat",  code: "DTN", qualifier: "F"},
        {abbr: "100 kg/br",            code: "DTN", qualifier: "G"},
        {abbr: "100 kg live weight",   code: "DTN", qualifier: "L"},
        {abbr: "100 kg/net mas",       code: "DTN", qualifier: "M"},
        {abbr: "100 kg std qual",      code: "DTN", qualifier: "R"},
        {abbr: "100 kg raw sugar",     code: "DTN", qualifier: "S"},
        {abbr: "100 kg/net/%sacchar.", code: "DTN", qualifier: "Z"},
        {abbr: "EUR",                  code: "EUR"},
        {abbr: "gi F/S",               code: "GFI"},
        {abbr: "g",                    code: "GRM"},
        {abbr: "GT",                   code: "GRT"},
        {abbr: "hl",                   code: "HLT"},
        {abbr: "100 m",                code: "HMT"},
        {abbr: "kg C₅H₁₄ClNO",         code: "KCC"},
        {abbr: "tonne KCl",            code: "KCL"},
        {abbr: "kg",                   code: "KGM"},
        {abbr: "kg/tot/alc",           code: "KGM", qualifier: "A"},
        {abbr: "kg/net eda",           code: "KGM", qualifier: "E"},
        {abbr: "GKG",                  code: "KGM", qualifier: "G"},
        {abbr: "kg/lactic matter",     code: "KGM", qualifier: "P"},
        {abbr: "kg/raw sugar",         code: "KGM", qualifier: "S"},
        {abbr: "kg/dry lactic matter", code: "KGM", qualifier: "T"},
        {abbr: "1000 l",               code: "KLT"},
        {abbr: "kg methylamines",      code: "KMA"},
        {abbr: "KM",                   code: "KMT"},
        {abbr: "kg N",                 code: "KNI"},
        {abbr: "kg H₂O₂",              code: "KNS"},
        {abbr: "kg KOH",               code: "KPH"},
        {abbr: "kg K₂O",               code: "KPO"},
        {abbr: "kg P₂O₅",              code: "KPP"},
        {abbr: "kg 90% sdt",           code: "KSD"},
        {abbr: "kg NaOH",              code: "KSH"},
        {abbr: "kg U",                 code: "KUR"},
        {abbr: "l alc. 100%",          code: "LPA"},
        {abbr: "l",                    code: "LTR"},
        {abbr: "L total alc.",         code: "LTR", qualifier: "A"},
        {abbr: "1000 p/st",            code: "MIL"},
        {abbr: "1000 pa",              code: "MPR"},
        {abbr: "m²",                   code: "MTK"},
        {abbr: "m³",                   code: "MTQ"},
        {abbr: "1000 m³",              code: "MTQ", qualifier: "C"},
        {abbr: "m",                    code: "MTR"},
        {abbr: "1000 kWh",             code: "MWH"},
        {abbr: "p/st",                 code: "NAR"},
        {abbr: "b/f",                  code: "NAR", qualifier: "B"},
        {abbr: "ce/el",                code: "NCL"},
        {abbr: "pa",                   code: "NPR"},
        {abbr: "TJ",                   code: "TJO"},
        {abbr: "1000 kg",              code: "TNE"},
        {abbr: "1000 kg/net eda",      code: "TNE", qualifier: "E"},
        {abbr: "1000 kg/biodiesel",    code: "TNE", qualifier: "I"},
        {abbr: "1000 kg/fuel content", code: "TNE", qualifier: "J"},
        {abbr: "1000 kg/bioethanol",   code: "TNE", qualifier: "K"},
        {abbr: "1000 kg/net mas",      code: "TNE", qualifier: "M"},
        {abbr: "1000 kg std qual",     code: "TNE", qualifier: "R"},
        {abbr: "1000 kg/net/%saccha.", code: "TNE", qualifier: "Z"},
        {abbr: "Watt",                 code: "WAT"} ].each do |m|
        MeasurementUnitAbbreviation.create(abbreviation: m[:abbr],
                                  measurement_unit_code: m[:code],
                             measurement_unit_qualifier: m[:qualifier])
      end
    }
  end

  down do
    applicable {
      MeasurementUnitAbbreviation.any?
      false
    }

    apply {
      MeasurementUnitAbbreviation.filter.delete
    }
  end
end
