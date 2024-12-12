module Loaders
  class MeasurementUnitQualifier < Base
    def self.load(file, batch)
      measurement_unit_qualifiers = []
      descriptions = []

      batch.each do |attributes|
        measurement_unit_qualifiers.push({
          measurement_unit_qualifier_code: attributes.dig('MeasurementUnitQualifier', 'measurementUnitQualifierCode'),
          validity_start_date: attributes.dig('MeasurementUnitQualifier', 'validityStartDate'),
          validity_end_date: attributes.dig('MeasurementUnitQualifier', 'validityEndDate'),
          operation: attributes.dig('MeasurementUnitQualifier', 'metainfo', 'opType'),
          operation_date: attributes.dig('MeasurementUnitQualifier', 'metainfo', 'transactionDate'),
          filename: file,
        })

        descriptions.push({
          measurement_unit_qualifier_code: attributes.dig('MeasurementUnitQualifier', 'measurementUnitQualifierCode'),
          language_id: attributes.dig('MeasurementUnitQualifier', 'measurementUnitQualifierDescription', 'language', 'languageId'),
          description: attributes.dig('MeasurementUnitQualifier', 'measurementUnitQualifierDescription', 'description'),
          operation: attributes.dig('MeasurementUnitQualifier', 'measurementUnitQualifierDescription', 'metainfo', 'opType'),
          operation_date: attributes.dig('MeasurementUnitQualifier', 'measurementUnitQualifierDescription', 'metainfo', 'transactionDate'),
          filename: file,
        })
      end

      Object.const_get('MeasurementUnitQualifier::Operation').multi_insert(measurement_unit_qualifiers)
      Object.const_get('MeasurementUnitQualifierDescription::Operation').multi_insert(descriptions)
    end
  end
end
