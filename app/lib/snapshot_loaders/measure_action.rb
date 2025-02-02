module SnapshotLoaders
  class MeasureAction < Base
    def self.load(file, batch)
      codes = []
      descriptions = []

      batch.each do |attributes|
        codes.push({
          action_code: attributes['MeasureAction']['actionCode'],
          validity_start_date: attributes['MeasureAction']['validityStartDate'],
          validity_end_date: attributes['MeasureAction']['validityEndDate'],
          operation: attributes['MeasureAction']['metainfo']['opType'],
          operation_date: attributes['MeasureAction']['metainfo']['transactionDate'],
          filename: file,
        })

        descriptions.push({
          action_code: attributes['MeasureAction']['actionCode'],
          language_id: attributes['MeasureAction']['measureActionDescription']['language']['languageId'],
          description: attributes['MeasureAction']['measureActionDescription']['description'],
          operation: attributes['MeasureAction']['measureActionDescription']['metainfo']['opType'],
          operation_date: attributes['MeasureAction']['measureActionDescription']['metainfo']['transactionDate'],
          filename: file,
        })
      end

      Object.const_get('MeasureAction::Operation').multi_insert(codes)
      Object.const_get('MeasureActionDescription::Operation').multi_insert(descriptions)
    end
  end
end
