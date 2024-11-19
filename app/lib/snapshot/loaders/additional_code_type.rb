module Loaders
  class AdditionalCodeType < Base
    def self.load(file, batch)
      additional_code_types = []
      descriptions = []
      measure_types = []


      batch.each do |attributes|
        additional_code_types.push({
          additional_code_type_id: attributes['AdditionalCodeType']['additionalCodeTypeId'],
          validity_start_date: attributes['AdditionalCodeType']['validityStartDate'],
          application_code: attributes['AdditionalCodeType']['applicationCode'],
          operation: attributes['AdditionalCodeType']['metainfo']['opType'],
          operation_date: attributes['AdditionalCodeType']['metainfo']['transactionDate'],
          filename: file,
        })

        descriptions.push({
          additional_code_type_id: attributes['AdditionalCodeType']['additionalCodeTypeId'],
          language_id: attributes['AdditionalCodeType']['additionalCodeTypeDescription']['languageId'],
          description: attributes['AdditionalCodeType']['additionalCodeTypeDescription']['description'],
          operation: attributes['AdditionalCodeType']['metainfo']['opType'],
          operation_date: attributes['AdditionalCodeType']['metainfo']['transactionDate'],
          filename: file,
        })

        attributes['AdditionalCodeType']['additionalCodeTypeMeasureType'].each do |measure_type|
          next unless measure_type.is_a?(Hash)

          measure_type_id = measure_type.dig('measureType', 'measureTypeId') || measure_type.dig('measureTypeId') # rubocop:disable Style/SingleArgumentDig

          next unless measure_type_id

          measure_types.push({
            additional_code_type_id: attributes['AdditionalCodeType']['additionalCodeTypeId'],
            measure_type_id: measure_type_id.to_i,
            validity_start_date: measure_type['measureType']['validityStartDate'],
            operation: measure_type['metainfo']['opType'],
            operation_date: measure_type['metainfo']['transactionDate'],
            filename: file,
          })
        end
      end

      Object.const_get('AdditionalCodeType::Operation').multi_insert(additional_code_types)
      Object.const_get('AdditionalCodeTypeDescription::Operation').multi_insert(descriptions)
      Object.const_get('AdditionalCodeTypeMeasureType::Operation').multi_insert(measure_types)
    end
  end
end
