class MeasurementUnitDescription < Sequel::Model
  plugin :oplog, primary_key: :measurement_unit_code

  set_primary_key [:measurement_unit_code]
end
