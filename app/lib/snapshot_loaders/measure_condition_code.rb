module SnapshotLoaders
  class MeasureConditionCode < Base
    def self.load(file, batch)
      codes = []
      descriptions = []

      batch.each do |attributes|
        codes.push({
          condition_code: attributes['MeasureConditionCode']['conditionCode'],
          validity_start_date: attributes['MeasureConditionCode']['validityStartDate'],
          validity_end_date: attributes['MeasureConditionCode']['validityEndDate'],
          operation: attributes['MeasureConditionCode']['metainfo']['opType'],
          operation_date: attributes['MeasureConditionCode']['metainfo']['transactionDate'],
          filename: file,
        })

        descriptions.push({
          condition_code: attributes['MeasureConditionCode']['conditionCode'],
          language_id: attributes['MeasureConditionCode']['measureConditionCodeDescription']['language']['languageId'],
          description: attributes['MeasureConditionCode']['measureConditionCodeDescription']['description'],
          operation: attributes['MeasureConditionCode']['measureConditionCodeDescription']['metainfo']['opType'],
          operation_date: attributes['MeasureConditionCode']['measureConditionCodeDescription']['metainfo']['transactionDate'],
          filename: file,
        })
      end

      Object.const_get('MeasureConditionCode::Operation').multi_insert(codes)
      Object.const_get('MeasureConditionCodeDescription::Operation').multi_insert(descriptions)
    end
  end
end
