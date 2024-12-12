module Loaders
  class AdditionalCode < Base
    def self.load(file, batch)
      additional_codes = []
      periods = []
      descriptions = []
      footnotes = []

      batch.each do |attributes|
        additional_codes.push({
          additional_code_sid: attributes.dig('AdditionalCode', 'sid'),
          additional_code_type_id: attributes.dig('AdditionalCode', 'additionalCodeType', 'additionalCodeTypeId'),
          additional_code: attributes.dig('AdditionalCode', 'additionalCodeCode'),
          validity_start_date: attributes.dig('AdditionalCode', 'validityStartDate'),
          validity_end_date: attributes.dig('AdditionalCode', 'validityEndDate'),
          operation: attributes.dig('AdditionalCode', 'metainfo', 'opType'),
          operation_date: attributes.dig('AdditionalCode', 'metainfo', 'transactionDate'),
          filename: file,
        })

        footnote_attributes = if attributes.dig('AdditionalCode', 'footnoteAssociationAdditionalCode').is_a?(Array)
                                attributes.dig('AdditionalCode', 'footnoteAssociationAdditionalCode')
                              else
                                Array.wrap(attributes.dig('AdditionalCode', 'footnoteAssociationAdditionalCode'))
                              end

        footnote_attributes.each do |footnote|
          next unless footnote.is_a?(Hash)

          footnotes.push({
            additional_code_sid: attributes.dig('AdditionalCode', 'sid'),
            additional_code_type_id: attributes.dig('AdditionalCode', 'additionalCodeType', 'additionalCodeTypeId'),
            additional_code: attributes.dig('AdditionalCode', 'additionalCodeCode'),
            footnote_id: footnote.dig('footnote', 'footnoteId'),
            footnote_type_id: footnote.dig('footnote', 'footnoteType', 'footnoteTypeId'),
            validity_start_date: footnote['validityStartDate'],
            validity_end_date: footnote['validityEndDate'],
            operation: footnote.dig('metainfo', 'opType'),
            operation_date: footnote.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end

        period_attributes = if attributes.dig('AdditionalCode', 'additionalCodeDescriptionPeriod').is_a?(Array)
                              attributes.dig('AdditionalCode', 'additionalCodeDescriptionPeriod')
                            else
                              Array.wrap(attributes.dig('AdditionalCode', 'additionalCodeDescriptionPeriod'))
                            end

        period_attributes.each do |period|
          periods.push({
            additional_code_sid: attributes.dig('AdditionalCode', 'sid'),
            additional_code_type_id: attributes.dig('AdditionalCode', 'additionalCodeType', 'additionalCodeTypeId'),
            additional_code_description_period_sid: period['sid'],
            additional_code: attributes.dig('AdditionalCode', 'additionalCodeCode'),
            validity_start_date: period['validityStartDate'],
            validity_end_date: period['validityEndDate'],
            operation: period.dig('metainfo', 'opType'),
            operation_date: period.dig('metainfo', 'transactionDate'),
            filename: file,
          })

          description = period['additionalCodeDescription']
          next unless description

          descriptions.push({
            additional_code_sid: attributes.dig('AdditionalCode', 'sid'),
            additional_code_type_id: attributes.dig('AdditionalCode', 'additionalCodeType', 'additionalCodeTypeId'),
            additional_code_description_period_sid: period['sid'],
            additional_code: attributes.dig('AdditionalCode', 'additionalCodeCode'),
            language_id: description.dig('language', 'languageId'),
            description: description['description'],
            operation: description.dig('metainfo', 'opType'),
            operation_date: description.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end
      end

      Object.const_get('AdditionalCode::Operation').multi_insert(additional_codes)
      Object.const_get('AdditionalCodeDescriptionPeriod::Operation').multi_insert(periods)
      Object.const_get('AdditionalCodeDescription::Operation').multi_insert(descriptions)
      Object.const_get('FootnoteAssociationAdditionalCode::Operation').multi_insert(footnotes)
    end
  end
end
