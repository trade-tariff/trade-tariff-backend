module Loaders
  class MeursingAdditionalCode < Base
    def self.load(file, batch)
      meursing_additional_codes = []
      meursing_cells = []

      batch.each do |attributes|
        meursing_additional_codes.push({
          meursing_additional_code_sid: attributes.dig('MeursingAdditionalCode', 'sid'),
          additional_code: attributes.dig('MeursingAdditionalCode', 'additionalCodeCode'),
          validity_start_date: attributes.dig('MeursingAdditionalCode', 'validityStartDate'),
          validity_end_date: attributes.dig('MeursingAdditionalCode', 'validityEndDate'),
          operation: attributes.dig('MeursingAdditionalCode', 'metainfo', 'opType'),
          operation_date: attributes.dig('MeursingAdditionalCode', 'metainfo', 'transactionDate'),
          filename: file,
        })

        attributes['MeursingAdditionalCode']['meursingCellComponent'].each do |cells|
          next unless cells.is_a?(Hash)

          meursing_cells.push({
            meursing_additional_code_sid: attributes.dig('MeursingAdditionalCode', 'sid'),
            additional_code: attributes.dig('MeursingAdditionalCode', 'additionalCodeCode'),
            meursing_table_plan_id: cells.dig('meursingSubheading', 'meursingHeading', 'meursingTablePlan', 'meursingTablePlanId'),
            heading_number: cells.dig('meursingSubheading', 'meursingHeading', 'meursingHeadingNumber'),
            row_column_code: cells.dig('meursingSubheading', 'meursingHeading', 'rowColumnCode'),
            subheading_sequence_number: cells.dig('meursingSubheading', 'subheadingSequenceNumber'),
            validity_start_date: cells['validityStartDate'],
            validity_end_date: cells['validityEndDate'],
            operation: cells.dig('metainfo', 'opType'),
            operation_date: cells.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end
      end

      Object.const_get('MeursingAdditionalCode::Operation').multi_insert(meursing_additional_codes)
      Object.const_get('MeursingTableCellComponent::Operation').multi_insert(meursing_cells)
    end
  end
end
