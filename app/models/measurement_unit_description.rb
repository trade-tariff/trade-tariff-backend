class MeasurementUnitDescription < Sequel::Model
  plugin :oplog, primary_key: :measurement_unit_code
  plugin :static_cache, frozen: false unless Rails.env.test?

  set_primary_key [:measurement_unit_code]
end
