module Loaders
  class MonetaryUnit < Base
    def self.load(file, batch)
      monetary_units = []
      descriptions = []

      batch.each do |attributes|
        monetary_units.push({
                              monetary_unit_code: attributes.dig('MonetaryUnit', 'monetaryUnitCode'),
                              validity_start_date: attributes.dig('MonetaryUnit', 'validityStartDate'),
                              validity_end_date: attributes.dig('MonetaryUnit', 'validityEndDate'),
                              operation: attributes.dig('MonetaryUnit', 'metainfo', 'opType'),
                              operation_date: attributes.dig('MonetaryUnit', 'metainfo', 'transactionDate'),
                              filename: file,
                            })

        descriptions.push({
                            monetary_unit_code: attributes.dig('MonetaryUnit', 'monetaryUnitCode'),
                            language_id: attributes.dig('MonetaryUnit', 'monetaryUnitDescription', 'language', 'languageId'),
                            description: attributes.dig('MonetaryUnit', 'monetaryUnitDescription', 'description'),
                            operation: attributes.dig('MonetaryUnit', 'monetaryUnitDescription', 'metainfo', 'opType'),
                            operation_date: attributes.dig('MonetaryUnit', 'monetaryUnitDescription', 'metainfo', 'transactionDate'),
                            filename: file,
                          })
      end

      Object.const_get('MonetaryUnit::Operation').multi_insert(monetary_units)
      Object.const_get('MonetaryUnitDescription::Operation').multi_insert(descriptions)
    end
  end
end
