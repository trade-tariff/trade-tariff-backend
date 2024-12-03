module Loaders
  class DutyExpression < Base
    def self.load(file, batch)
      duty_expressions = []
      descriptions = []

      batch.each do |attributes|
        duty_expressions.push({
                                 duty_expression_id: attributes.dig('DutyExpression', 'dutyExpressionId'),
                                 validity_start_date: attributes.dig('DutyExpression', 'validityStartDate'),
                                 validity_end_date: attributes.dig('DutyExpression', 'validityEndDate'),
                                 duty_amount_applicability_code: attributes.dig('DutyExpression', 'dutyAmountApplicabilityCode'),
                                 measurement_unit_applicability_code: attributes.dig('DutyExpression', 'measurementUnitApplicabilityCode'),
                                 monetary_unit_applicability_code: attributes.dig('DutyExpression', 'monetaryUnitApplicabilityCode'),
                                 operation: attributes.dig('DutyExpression', 'metainfo', 'opType'),
                                 operation_date: attributes.dig('DutyExpression', 'metainfo', 'transactionDate'),
                                 filename: file,
                               })

        descriptions.push({
                            duty_expression_id: attributes.dig('DutyExpression', 'dutyExpressionId'),
                            language_id: attributes.dig('DutyExpression', 'dutyExpressionDescription', 'language', 'languageId'),
                            description: attributes.dig('DutyExpression', 'dutyExpressionDescription', 'description'),
                            operation: attributes.dig('DutyExpression', 'dutyExpressionDescription', 'metainfo', 'opType'),
                            operation_date: attributes.dig('DutyExpression', 'dutyExpressionDescription', 'metainfo', 'transactionDate'),
                            filename: file,
                          })
      end

      Object.const_get('DutyExpression::Operation').multi_insert(duty_expressions)
      Object.const_get('DutyExpressionDescription::Operation').multi_insert(descriptions)
    end
  end
end
