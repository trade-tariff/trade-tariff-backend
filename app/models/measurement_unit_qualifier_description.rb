class MeasurementUnitQualifierDescription < Sequel::Model
  include Formatter

  plugin :oplog, primary_key: :measurement_unit_qualifier_code

  set_primary_key [:measurement_unit_qualifier_code]

  custom_format :formatted_measurement_unit_qualifier, with: DescriptionFormatter,
                                                using: :description
end
