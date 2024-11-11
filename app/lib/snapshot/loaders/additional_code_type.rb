module Loaders
  class AdditionalCodeType < Base
    def self.load(file, attributes)
      Object.const_get('AdditionalCodeType::Operation').create({
        additional_code_type_id: attributes['AdditionalCodeType']['additionalCodeTypeId'],
        validity_start_date: attributes['AdditionalCodeType']['validityStartDate'],
        application_code: attributes['AdditionalCodeType']['applicationCode'],
        operation: attributes['AdditionalCodeType']['metainfo']['opType'],
        operation_date: attributes['AdditionalCodeType']['metainfo']['transactionDate'],
        filename: file,
      })

      Object.const_get('AdditionalCodeTypeDescription::Operation').create({
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

        Object.const_get('AdditionalCodeTypeMeasureType::Operation').create({
          additional_code_type_id: attributes['AdditionalCodeType']['additionalCodeTypeId'],
          measure_type_id: measure_type_id.to_i,
          validity_start_date: measure_type['measureType']['validityStartDate'],
          operation: measure_type['metainfo']['opType'],
          operation_date: measure_type['metainfo']['transactionDate'],
          filename: file,
        })
      end
    end
  end
end
