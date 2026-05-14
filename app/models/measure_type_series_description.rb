class MeasureTypeSeriesDescription < Sequel::Model
  set_primary_key [:measure_type_series_id]

  plugin :oplog, primary_key: :measure_type_series_id
  plugin :static_cache, frozen: false unless Rails.env.test?
end
