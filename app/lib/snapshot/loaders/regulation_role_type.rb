module Loaders
  class RegulationRoleType < Base
    def self.load(file, batch)
      regulation_groups = []
      descriptions = []

      batch.each do |attributes|
        regulation_groups.push({
          regulation_role_type_id: attributes.dig('RegulationRoleType', 'regulationRoleTypeId'),
          # national: attributes.dig('RegulationRoleType',''),
          validity_start_date: attributes.dig('RegulationRoleType', 'validityStartDate'),
          validity_end_date: attributes.dig('RegulationRoleType', 'validityEndDate'),
          operation: attributes.dig('RegulationRoleType', 'metainfo', 'opType'),
          operation_date: attributes.dig('RegulationRoleType', 'metainfo', 'transactionDate'),
          filename: file,
        })

        descriptions.push({
          regulation_role_type_id: attributes.dig('RegulationRoleType', 'regulationRoleTypeId'),
          language_id: attributes.dig('RegulationRoleType', 'regulationRoleTypeDescription', 'language', 'languageId'),
          description: attributes.dig('RegulationRoleType', 'regulationRoleTypeDescription', 'description'),
          # national: attributes.dig('RegulationRoleType', 'regulationRoleTypeDescription',''),
          operation: attributes.dig('RegulationRoleType', 'regulationRoleTypeDescription', 'metainfo', 'opType'),
          operation_date: attributes.dig('RegulationRoleType', 'regulationRoleTypeDescription', 'metainfo', 'transactionDate'),
          filename: file,
        })
      end

      Object.const_get('RegulationRoleType::Operation').multi_insert(regulation_groups)
      Object.const_get('RegulationRoleTypeDescription::Operation').multi_insert(descriptions)
    end
  end
end
