class MeasurementUnitDescription < Sequel::Model
  set_primary_key [:measurement_unit_code]

  plugin :oplog, primary_key: :measurement_unit_code
  plugin :static_cache, frozen: false unless Rails.env.test?
end
