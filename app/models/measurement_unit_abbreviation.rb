class MeasurementUnitAbbreviation < Sequel::Model
  one_to_one :measurement_unit, primary_key: :measurement_unit_code,
                                key: :measurement_unit_code
end
