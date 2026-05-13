class MeasurementUnitAbbreviation < Sequel::Model
  plugin :static_cache, frozen: false unless Rails.env.test?

  one_to_one :measurement_unit, primary_key: :measurement_unit_code,
                                key: :measurement_unit_code
end
