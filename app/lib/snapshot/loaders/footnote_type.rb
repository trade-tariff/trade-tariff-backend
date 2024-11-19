module Loaders
  class FootnoteType < Base
    def self.load(file, batch)
      footnote_types = []
      descriptions = []

      batch.each do |attributes|
        footnote_types.push({
          footnote_type_id: attributes['FootnoteType']['footnoteTypeId'],
          application_code: attributes['FootnoteType']['applicationCode'],
          validity_start_date: attributes['FootnoteType']['validityStartDate'],
          validity_end_date: attributes['FootnoteType']['validityEndDate'],
          operation: attributes['FootnoteType']['metainfo']['opType'],
          operation_date: attributes['FootnoteType']['metainfo']['transactionDate'],
          filename: file,
        })

        descriptions.push({
          footnote_type_id: attributes['FootnoteType']['footnoteTypeId'],
          language_id: attributes['FootnoteType']['footnoteTypeDescription']['languageId'],
          description: attributes['FootnoteType']['footnoteTypeDescription']['description'],
          operation: attributes['FootnoteType']['footnoteTypeDescription']['metainfo']['opType'],
          operation_date: attributes['FootnoteType']['footnoteTypeDescription']['metainfo']['transactionDate'],
          filename: file,
        })
      end

      Object.const_get('FootnoteType::Operation').multi_insert(footnote_types)
      Object.const_get('FootnoteTypeDescription::Operation').multi_insert(descriptions)
    end
  end
end
