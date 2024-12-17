module SnapshotLoaders
  class MeursingTablePlan < Base
    def self.load(file, batch)
      meursing_table_plans = []
      meursing_headings = []
      footnote_associations = []
      texts = []
      meursing_subheadings = []

      batch.each do |attributes|
        meursing_table_plans.push({
          meursing_table_plan_id: attributes.dig('MeursingTablePlan', 'meursingTablePlanId'),
          validity_start_date: attributes.dig('MeursingTablePlan', 'validityStartDate'),
          validity_end_date: attributes.dig('MeursingTablePlan', 'validityEndDate'),
          operation: attributes.dig('MeursingTablePlan', 'metainfo', 'opType'),
          operation_date: attributes.dig('MeursingTablePlan', 'metainfo', 'transactionDate'),
          filename: file,
        })

        attributes['MeursingTablePlan']['meursingHeading'].each do |heading|
          next unless heading.is_a?(Hash)

          meursing_headings.push({
            meursing_table_plan_id: attributes.dig('MeursingTablePlan', 'meursingTablePlanId'),
            meursing_heading_number: heading['meursingHeadingNumber'],
            row_column_code: heading['rowColumnCode'],
            validity_start_date: heading['validityStartDate'],
            validity_end_date: heading['validityEndDate'],
            operation: heading.dig('metainfo', 'opType'),
            operation_date: heading.dig('metainfo', 'transactionDate'),
            filename: file,
          })

          footnote_associations.push({
            meursing_table_plan_id: attributes.dig('MeursingTablePlan', 'meursingTablePlanId'),
            meursing_heading_number: heading['meursingHeadingNumber'],
            row_column_code: heading['rowColumnCode'],
            footnote_type: heading.dig('footnoteAssociationMeursingHeading', 'footnote', 'footnoteType', 'footnoteTypeId'),
            footnote_id: heading.dig('footnoteAssociationMeursingHeading', 'footnote', 'footnoteId'),
            validity_start_date: heading.dig('footnoteAssociationMeursingHeading', 'validityStartDate'),
            validity_end_date: heading.dig('footnoteAssociationMeursingHeading', 'validityEndDate'),
            operation: heading.dig('footnoteAssociationMeursingHeading', 'metainfo', 'opType'),
            operation_date: heading.dig('footnoteAssociationMeursingHeading', 'metainfo', 'transactionDate'),
            filename: file,
          })

          texts.push({
            meursing_table_plan_id: attributes.dig('MeursingTablePlan', 'meursingTablePlanId'),
            meursing_heading_number: heading['meursingHeadingNumber'],
            row_column_code: heading['rowColumnCode'],
            language_id: heading.dig('meursingHeadingText', 'language', 'languageId'),
            description: heading.dig('meursingHeadingText', 'description'),
            operation: heading.dig('meursingHeadingText', 'metainfo', 'opType'),
            operation_date: heading.dig('meursingHeadingText', 'metainfo', 'transactionDate'),
            filename: file,
          })

          heading['meursingSubheading'].each do |subheading|
            next unless subheading.is_a?(Hash)

            meursing_subheadings.push({
              meursing_table_plan_id: attributes.dig('MeursingTablePlan', 'meursingTablePlanId'),
              meursing_heading_number: heading['meursingHeadingNumber'],
              row_column_code: heading['rowColumnCode'],
              subheading_sequence_number: subheading['subheadingSequenceNumber'],
              description: subheading['description'],
              operation: subheading.dig('metainfo', 'opType'),
              operation_date: subheading.dig('metainfo', 'transactionDate'),
              filename: file,
            })
          end
        end
      end

      Object.const_get('MeursingTablePlan::Operation').multi_insert(meursing_table_plans)
      Object.const_get('MeursingHeading::Operation').multi_insert(meursing_headings)
      Object.const_get('FootnoteAssociationMeursingHeading::Operation').multi_insert(footnote_associations)
      Object.const_get('MeursingHeadingText::Operation').multi_insert(texts)
      Object.const_get('MeursingSubheading::Operation').multi_insert(meursing_subheadings)
    end
  end
end
