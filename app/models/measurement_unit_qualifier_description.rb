class MeasurementUnitQualifierDescription < Sequel::Model
  include Formatter

  set_primary_key [:measurement_unit_qualifier_code]

  plugin :oplog, primary_key: :measurement_unit_qualifier_code
  plugin :static_cache, frozen: false unless Rails.env.test?

  custom_format :formatted_measurement_unit_qualifier, with: DescriptionFormatter,
                                                       using: :description
end
