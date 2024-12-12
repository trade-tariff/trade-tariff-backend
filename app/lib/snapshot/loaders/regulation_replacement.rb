module Loaders
  class RegulationReplacement < Base
    def self.load(file, batch)
      regs = []

      batch.each do |attributes|
        regs.push({
          geographical_area_id: attributes.dig('RegulationReplacement', 'geographicalArea', 'geographicalAreaId'),
          chapter_heading: attributes.dig('RegulationReplacement', 'chapterHeading'),
          replacing_regulation_role: attributes.dig('RegulationReplacement', 'replacingRegulationRole'),
          replacing_regulation_id: attributes.dig('RegulationReplacement', 'replacingRegulationId'),
          replaced_regulation_role: attributes.dig('RegulationReplacement', 'replacedRegulationRole'),
          replaced_regulation_id: attributes.dig('RegulationReplacement', 'replacedRegulationId'),
          measure_type_id: attributes.dig('RegulationReplacement', 'measureType', 'measureTypeId'),
          operation: attributes.dig('RegulationReplacement', 'metainfo', 'opType'),
          operation_date: attributes.dig('RegulationReplacement', 'metainfo', 'transactionDate'),
          filename: file,
        })
      end

      Object.const_get('RegulationReplacement::Operation').multi_insert(regs)
    end
  end
end
