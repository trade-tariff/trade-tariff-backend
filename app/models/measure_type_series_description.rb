class MeasureTypeSeriesDescription < Sequel::Model
  plugin :oplog, primary_key: :measure_type_series_id

  set_primary_key [:measure_type_series_id]
end
