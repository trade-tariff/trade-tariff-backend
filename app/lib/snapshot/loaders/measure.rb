module Loaders
  class Measure < Base
    def self.load(file, batch)
      measures = []
      measure_components = []

      batch.each do |attributes|
        measures.push({
          measure_type_id: attributes.dig('Measure','measureType','measureTypeId'),
          geographical_area_id: attributes.dig('Measure','geographicalArea','geographicalAreaId'),
          goods_nomenclature_item_id: attributes.dig('Measure','goodsNomenclature','goodsNomenclatureItemId'),
          validity_start_date: attributes.dig('Measure','validityEndDate'),
          validity_end_date: attributes.dig('Measure','validityEndDate'),
          measure_generating_regulation_role: attributes.dig('Measure','measureGeneratingRegulationRole','regulationRoleTypeId'),
          measure_generating_regulation_id: attributes.dig('Measure','measureGeneratingRegulationId'),
          justification_regulation_role: attributes.dig('Measure','justificationRegulationRole','regulationRoleTypeId'),
          justification_regulation_id: attributes.dig('Measure','justificationRegulationId'),
          stopped_flag: attributes.dig('Measure','stoppedFlag'),
          geographical_area_sid: attributes.dig('Measure','geographicalArea','sid'),
          goods_nomenclature_sid: attributes.dig('Measure','goodsNomenclature','sid'),
          ordernumber: attributes.dig('Measure','ordernumber'),
          additional_code_type_id: attributes.dig('Measure','additionalCode','additionalCodeType','additionalCodeTypeId'),
          additional_code_id: attributes.dig('Measure','additionalCode','additionalCodeCode'),
          additional_code_sid: attributes.dig('Measure','additionalCode','sid'),
          reduction_indicator: attributes.dig('Measure','reductionIndicator'),
          export_refund_nomenclature_sid: attributes.dig('Measure','exportRefundNomenclature','goodsNomenclature','sid'),
          # national: attributes.dig('Measure',''),
          # tariff_measure_number: attributes.dig('Measure',''),
          operation: attributes.dig('Measure','metainfo','opType'),
          operation_date: attributes.dig('Measure','metainfo','transactionDate'),
          filename: file,
        })

        measure_component = attributes.dig('Measure', 'measureComponent')

        if measure_component.present? do
          measure_components.push({
              measure_sid: attributes.dig('Measure','sid'),
              duty_expression_id: attributes.dig('Measure','measureComponent','dutyExpression','dutyExpressionId'),
              duty_amount: attributes.dig('Measure','measureComponent','dutyAmount'),
              monetary_unit_code: attributes.dig('Measure','measureComponent','measurementUnit','measurementUnitCode'),
              measurement_unit_code: attributes.dig('Measure','measureComponent','monetaryUnit','monetaryUnitCode'),
              measurement_unit_qualifier_code: attributes.dig('Measure','measureComponent','measurementUnitQualifier','measurementUnitQualifierCode'),
              operation: attributes.dig('Measure','measureComponent','metainfo','opType'),
              operation_date: attributes.dig('Measure','measureComponent','metainfo','transactionDate'),
              filename: file,
            })
          end
        end
      end

      Object.const_get('Measure::Operation').multi_insert(measures)
      Object.const_get('MeasureComponent::Operation').multi_insert(measure_components)
    end
  end
end
