TradeTariffBackend::DataMigrator.migration do
  name "Rename San Marino to Italy on national measures"
  desc "This is for excluded geographical areas. Related to commit #3951ff024bc , invalid original data."

  up do
    applicable {
      MeasureExcludedGeographicalArea::Operation.where(excluded_geographical_area: 'IT').where("measure_sid < 0").any?
      false
    }
    apply {
      MeasureExcludedGeographicalArea::Operation.where(excluded_geographical_area: 'IT').where("measure_sid < 0").update(geographical_area_sid: 382, excluded_geographical_area: 'SM')
    }
  end

  down do
    applicable {
      MeasureExcludedGeographicalArea::Operation.where(excluded_geographical_area: 'SM').where("measure_sid < 0").any?
      false
    }
    apply {
      MeasureExcludedGeographicalArea::Operation.where(excluded_geographical_area: 'SM').where("measure_sid < 0").update(geographical_area_sid: 270, excluded_geographical_area: 'IT')
    }
  end
end
