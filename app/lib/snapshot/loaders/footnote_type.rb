module Loaders
  class FootnoteType < Base
    def self.load(file, attributes)
      Object.const_get('FootnoteType::Operation').create({
        footnote_type_id: attributes['FootnoteType']['footnoteTypeId'],
        application_code: attributes['FootnoteType']['applicationCode'],
        validity_start_date: attributes['FootnoteType']['validityStartDate'],
        validity_end_date: attributes['FootnoteType']['validityEndDate'],
        operation: attributes['FootnoteType']['metainfo']['opType'],
        operation_date: attributes['FootnoteType']['metainfo']['transactionDate'],
        filename: file,
      })

      Object.const_get('FootnoteTypeDescription::Operation').create({
        footnote_type_id: attributes['FootnoteType']['footnoteTypeId'],
        language_id: attributes['FootnoteType']['footnoteTypeDescription']['languageId'],
        description: attributes['FootnoteType']['footnoteTypeDescription']['description'],
        operation: attributes['FootnoteType']['footnoteTypeDescription']['metainfo']['opType'],
        operation_date: attributes['FootnoteType']['footnoteTypeDescription']['metainfo']['transactionDate'],
        filename: file,
      })
    end
  end
end
