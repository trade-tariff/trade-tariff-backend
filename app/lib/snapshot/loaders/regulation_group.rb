module Loaders
  class RegulationGroup < Base
    def self.load(file, batch)
      regulation_groups = []
      descriptions = []

      batch.each do |attributes|
        regulation_groups.push({
                                 regulation_group_id: attributes.dig('RegulationGroup', 'regulationGroupId'),
                                 # national: attributes.dig('RegulationGroup',''),
                                 validity_start_date: attributes.dig('RegulationGroup', 'validityStartDate'),
                                 validity_end_date: attributes.dig('RegulationGroup', 'validityEndDate'),
                                 operation: attributes.dig('RegulationGroup', 'metainfo', 'opType'),
                                 operation_date: attributes.dig('RegulationGroup', 'metainfo', 'transactionDate'),
                                 filename: file,
                               })

        descriptions.push({
                            regulation_group_id: attributes.dig('RegulationGroup', 'regulationGroupId'),
                            language_id: attributes.dig('RegulationGroup', 'regulationGroupDescription', 'language', 'languageId'),
                            description: attributes.dig('RegulationGroup', 'regulationGroupDescription', 'description'),
                            # national: attributes.dig('RegulationGroup','regulationGroupDescription',''),
                            operation: attributes.dig('RegulationGroup', 'regulationGroupDescription', 'metainfo', 'opType'),
                            operation_date: attributes.dig('RegulationGroup', 'regulationGroupDescription', 'metainfo', 'transactionDate'),
                            filename: file,
                          })
      end

      Object.const_get('RegulationGroup::Operation').multi_insert(regulation_groups)
      Object.const_get('RegulationGroupDescription::Operation').multi_insert(descriptions)
    end
  end
end
