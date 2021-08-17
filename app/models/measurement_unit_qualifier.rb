class MeasurementUnitQualifier < Sequel::Model
  plugin :time_machine
  plugin :oplog, primary_key: :measurement_unit_qualifier_code

  set_primary_key [:measurement_unit_qualifier_code]

  one_to_one :measurement_unit_qualifier_description, key: :measurement_unit_qualifier_code,
                                                      primary_key: :measurement_unit_qualifier_code

  delegate :formatted_measurement_unit_qualifier, :description, to: :measurement_unit_qualifier_description, allow_nil: true
end
