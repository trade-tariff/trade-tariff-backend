module Loaders
  class MeasureTypeSeries < Base
    def self.load(file, batch)
      measure_type_series = []
      descriptions = []

      batch.each do |attributes|
        measure_type_series.push({
                                   measure_type_series_id: attributes.dig('MeasureTypeSeries', 'measureTypeSeriesId'),
                                   measure_type_combination: attributes.dig('MeasureTypeSeries', 'measureTypeCombination'),
                                   validity_start_date: attributes.dig('MeasureTypeSeries', 'validityStartDate'),
                                   validity_end_date: attributes.dig('MeasureTypeSeries', 'validityEndDate'),
                                   operation: attributes.dig('MeasureTypeSeries', 'metainfo', 'opType'),
                                   operation_date: attributes.dig('MeasureTypeSeries', 'metainfo', 'transactionDate'),
                                   filename: file,
                                 })

        descriptions.push({
                            measure_type_series_id: attributes.dig('MeasureTypeSeries', 'measureTypeSeriesId'),
                            language_id: attributes.dig('MeasureTypeSeries', 'measureTypeSeriesDescription', 'language', 'languageId'),
                            description: attributes.dig('MeasureTypeSeries', 'measureTypeSeriesDescription', 'description'),
                            operation: attributes.dig('MeasureTypeSeries', 'measureTypeSeriesDescription', 'metainfo', 'opType'),
                            operation_date: attributes.dig('MeasureTypeSeries', 'measureTypeSeriesDescription', 'metainfo', 'transactionDate'),
                            filename: file,
                          })
      end

      Object.const_get('MeasureTypeSeries::Operation').multi_insert(measure_type_series)
      Object.const_get('MeasureTypeSeriesDescription::Operation').multi_insert(descriptions)
    end
  end
end
