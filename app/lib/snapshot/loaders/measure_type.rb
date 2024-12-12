module Loaders
  class MeasureType < Base
    def self.load(file, batch)
      measure_types = []
      descriptions = []

      batch.each do |attributes|
        measure_types.push({
          measure_type_id: attributes.dig('MeasureType', 'measureTypeId'),
          trade_movement_code: attributes.dig('MeasureType', 'tradeMovementCode'),
          priority_code: attributes.dig('MeasureType', 'priorityCode'),
          measure_component_applicable_code: attributes.dig('MeasureType', 'measureComponentApplicableCode'),
          origin_dest_code: attributes.dig('MeasureType', 'originDestCode'),
          order_number_capture_code: attributes.dig('MeasureType', 'orderNumberCaptureCode'),
          measure_explosion_level: attributes.dig('MeasureType', 'measureExplosionLevel'),
          measure_type_series_id: attributes.dig('MeasureType', 'measureTypeSeries', 'measureTypeSeriesId'),
          validity_start_date: attributes.dig('MeasureType', 'validityStartDate'),
          validity_end_date: attributes.dig('MeasureType', 'validityEndDate'),
          operation: attributes.dig('MeasureType', 'metainfo', 'opType'),
          operation_date: attributes.dig('MeasureType', 'metainfo', 'transactionDate'),
          filename: file,
        })

        descriptions.push({
          measure_type_id: attributes.dig('MeasureType', 'measureTypeId'),
          language_id: attributes.dig('MeasureType', 'measureTypeDescription', 'language', 'languageId'),
          description: attributes.dig('MeasureType', 'measureTypeDescription', 'description'),
          operation: attributes.dig('MeasureType', 'measureTypeDescription', 'metainfo', 'opType'),
          operation_date: attributes.dig('MeasureType', 'measureTypeDescription', 'metainfo', 'transactionDate'),
          filename: file,
        })
      end

      Object.const_get('MeasureType::Operation').multi_insert(measure_types)
      Object.const_get('MeasureTypeDescription::Operation').multi_insert(descriptions)
    end
  end
end
