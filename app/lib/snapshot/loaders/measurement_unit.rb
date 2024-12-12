module Loaders
  class MeasurementUnit < Base
    def self.load(file, batch)
      measurement_units = []
      descriptions = []
      measurements = []

      batch.each do |attributes|
        measurement_units.push({
          measurement_unit_code: attributes.dig('MeasurementUnit', 'measurementUnitCode'),
          validity_start_date: attributes.dig('MeasurementUnit', 'validityStartDate'),
          validity_end_date: attributes.dig('MeasurementUnit', 'validityEndDate'),
          operation: attributes.dig('MeasurementUnit', 'metainfo', 'opType'),
          operation_date: attributes.dig('MeasurementUnit', 'metainfo', 'transactionDate'),
          filename: file,
        })

        descriptions.push({
          measurement_unit_code: attributes.dig('MeasurementUnit', 'measurementUnitCode'),
          language_id: attributes.dig('MeasurementUnit', 'measurementUnitDescription', 'language', 'languageId'),
          description: attributes.dig('MeasurementUnit', 'measurementUnitDescription', 'description'),
          operation: attributes.dig('MeasurementUnit', 'measurementUnitDescription', 'metainfo', 'opType'),
          operation_date: attributes.dig('MeasurementUnit', 'measurementUnitDescription', 'metainfo', 'transactionDate'),
          filename: file,
        })

        qualifiers = attributes['MeasurementUnit']['measurementUnitQualifier']
        next unless qualifiers

        qualifiers.each do |measurement|
          next unless measurement.is_a?(Hash)

          measurements.push({
            measurement_unit_code: attributes.dig('MeasurementUnit', 'measurementUnitCode'),
            measurement_unit_qualifier_code: measurement['measurementUnitQualifierCode'],
            validity_start_date: attributes.dig('MeasurementUnit', 'validityStartDate'),
            validity_end_date: attributes.dig('MeasurementUnit', 'validityEndDate'),
            operation: attributes.dig('MeasurementUnit', 'metainfo', 'opType'),
            operation_date: attributes.dig('MeasurementUnit', 'metainfo', 'transactionDate'),
            filename: file,
          })
        end
      end

      Object.const_get('MeasurementUnit::Operation').multi_insert(measurement_units)
      Object.const_get('Measurement::Operation').multi_insert(measurements)
      Object.const_get('MeasurementUnitDescription::Operation').multi_insert(descriptions)
    end
  end
end
