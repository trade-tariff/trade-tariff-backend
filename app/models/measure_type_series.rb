class MeasureTypeSeries < Sequel::Model
  set_primary_key [:measure_type_series_id]
  plugin :oplog, primary_key: :measure_type_series_id

  one_to_many :measure_types
end
