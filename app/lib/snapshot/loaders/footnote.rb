module Loaders
  class Footnote < Base
    def self.load(file, batch)
      footnotes = []
      periods = []
      descriptions = []

      batch.each do |attributes|
        footnotes.push({
          footnote_id: attributes.dig('Footnote', 'footnoteId'),
          footnote_type_id: attributes.dig('Footnote', 'footnoteType', 'footnoteTypeId'),
          validity_start_date: attributes.dig('Footnote', 'validityStartDate'),
          validity_end_date: attributes.dig('Footnote', 'validityEndDate'),
          operation: attributes.dig('Footnote', 'metainfo', 'opType'),
          operation_date: attributes.dig('Footnote', 'metainfo', 'transactionDate'),
          filename: file,
        })

        period_attributes = if attributes.dig('Footnote', 'footnoteDescriptionPeriod').is_a?(Array)
                              attributes.dig('Footnote', 'footnoteDescriptionPeriod')
                            else
                              Array.wrap(attributes.dig('Footnote', 'footnoteDescriptionPeriod'))
                            end

        period_attributes.each do |period|
          periods.push({
            footnote_id: attributes.dig('Footnote', 'regulationGroupId'),
            footnote_type_id: attributes.dig('Footnote', 'footnoteType', 'footnoteTypeId'),
            footnote_description_period_sid: period['sid'],
            validity_start_date: period['validityStartDate'],
            validity_end_date: period['validityEndDate'],
            operation: period.dig('metainfo', 'opType'),
            operation_date: period.dig('metainfo', 'transactionDate'),
            filename: file,
          })

          description = period['footnoteDescription']
          next unless description

          descriptions.push({
            footnote_id: attributes.dig('Footnote', 'regulationGroupId'),
            footnote_type_id: attributes.dig('Footnote', 'footnoteType', 'footnoteTypeId'),
            footnote_description_period_sid: period['sid'],
            language_id: description.dig('language', 'languageId'),
            description: description['description'],
            operation: description.dig('metainfo', 'opType'),
            operation_date: description.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end
      end

      Object.const_get('Footnote::Operation').multi_insert(footnotes)
      Object.const_get('FootnoteDescriptionPeriod::Operation').multi_insert(periods)
      Object.const_get('FootnoteDescription::Operation').multi_insert(descriptions)
    end
  end
end
