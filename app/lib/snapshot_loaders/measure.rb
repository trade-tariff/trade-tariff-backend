module SnapshotLoaders
  class Measure < Base
    def self.load(file, batch)
      measures = []
      measure_components = []
      measure_conditions = []
      measure_condition_components = []
      geographical_areas = []
      partial_stops = []
      footnotes = []

      batch.each do |attributes|
        measures.push({
          measure_sid: attributes.dig('Measure', 'sid'),
          measure_type_id: attributes.dig('Measure', 'measureType', 'measureTypeId'),
          geographical_area_id: attributes.dig('Measure', 'geographicalArea', 'geographicalAreaId'),
          goods_nomenclature_item_id: attributes.dig('Measure', 'goodsNomenclature', 'goodsNomenclatureItemId'),
          validity_start_date: attributes.dig('Measure', 'validityEndDate'),
          validity_end_date: attributes.dig('Measure', 'validityEndDate'),
          measure_generating_regulation_role: attributes.dig('Measure', 'measureGeneratingRegulationRole', 'regulationRoleTypeId'),
          measure_generating_regulation_id: attributes.dig('Measure', 'measureGeneratingRegulationId'),
          justification_regulation_role: attributes.dig('Measure', 'justificationRegulationRole', 'regulationRoleTypeId'),
          justification_regulation_id: attributes.dig('Measure', 'justificationRegulationId'),
          stopped_flag: attributes.dig('Measure', 'stoppedFlag'),
          geographical_area_sid: attributes.dig('Measure', 'geographicalArea', 'sid'),
          goods_nomenclature_sid: attributes.dig('Measure', 'goodsNomenclature', 'sid'),
          ordernumber: attributes.dig('Measure', 'ordernumber'),
          additional_code_type_id: attributes.dig('Measure', 'additionalCode', 'additionalCodeType', 'additionalCodeTypeId'),
          additional_code_id: attributes.dig('Measure', 'additionalCode', 'additionalCodeCode'),
          additional_code_sid: attributes.dig('Measure', 'additionalCode', 'sid'),
          reduction_indicator: attributes.dig('Measure', 'reductionIndicator'),
          export_refund_nomenclature_sid: attributes.dig('Measure', 'exportRefundNomenclature', 'goodsNomenclature', 'sid'),
          operation: attributes.dig('Measure', 'metainfo', 'opType'),
          operation_date: attributes.dig('Measure', 'metainfo', 'transactionDate'),
          filename: file,
        })

        component_attributes = if attributes.dig('Measure', 'measureComponent').is_a?(Array)
                                 attributes.dig('Measure', 'measureComponent')
                               else
                                 Array.wrap(attributes.dig('Measure', 'measureComponent'))
                               end

        component_attributes.each do |measure_component|
          next unless measure_component.is_a?(Hash)

          measure_components.push({
            measure_sid: attributes.dig('Measure', 'sid'),
            duty_expression_id: measure_component.dig('dutyExpression', 'dutyExpressionId'),
            duty_amount: measure_component['dutyAmount'],
            monetary_unit_code: measure_component.dig('measurementUnit', 'measurementUnitCode'),
            measurement_unit_code: measure_component.dig('monetaryUnit', 'monetaryUnitCode'),
            measurement_unit_qualifier_code: measure_component.dig('measurementUnitQualifier', 'measurementUnitQualifierCode'),
            operation: measure_component.dig('metainfo', 'opType'),
            operation_date: measure_component.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end

        footnote_attributes = if attributes.dig('Measure', 'footnoteAssociationMeasure').is_a?(Array)
                                attributes.dig('Measure', 'footnoteAssociationMeasure')
                              else
                                Array.wrap(attributes.dig('Measure', 'footnoteAssociationMeasure'))
                              end

        footnote_attributes.each do |footnote|
          next unless footnote.is_a?(Hash)

          footnotes.push({
            measure_sid: attributes.dig('Measure', 'sid'),
            footnote_id: footnote.dig('footnote', 'footnoteId'),
            footnote_type_id: footnote.dig('footnote', 'footnoteType', 'footnoteTypeId'),
            operation: footnote.dig('metainfo', 'opType'),
            operation_date: footnote.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end

        condition_attributes = if attributes.dig('Measure', 'measureCondition').is_a?(Array)
                                 attributes.dig('Measure', 'measureCondition')
                               else
                                 Array.wrap(attributes.dig('Measure', 'measureCondition'))
                               end

        condition_attributes.each do |measure_condition|
          next unless measure_condition.is_a?(Hash)

          measure_conditions.push({
            measure_sid: attributes.dig('Measure', 'sid'),
            measure_condition_sid: measure_condition['sid'],
            condition_code: measure_condition.dig('measureConditionCode', 'conditionCode'),
            component_sequence_number: measure_condition['conditionSequenceNumber'],
            condition_duty_amount: measure_condition['conditionDutyAmount'],
            action_code: measure_condition.dig('measureAction', 'actionCode'),
            certificate_code: measure_condition.dig('certificate', 'certificateCode'),
            certificate_type_code: measure_condition.dig('certificate', 'certificateType', 'certificateTypeCode'),
            condition_monetary_unit_code: measure_condition.dig('monetaryUnit', 'monetaryUnitCode'),
            condition_measurement_unit_code: measure_condition.dig('measurementUnit', 'measurementUnitCode'),
            condition_measurement_unit_qualifier_code: measure_condition.dig('measurementUnitQualifier', 'measurementUnitQualifierCode'),
            operation: measure_condition.dig('metainfo', 'opType'),
            operation_date: measure_condition.dig('metainfo', 'transactionDate'),
            filename: file,
          })

          condition_component_attributes = if measure_condition['measureConditionComponent'].is_a?(Array)
                                             measure_condition['measureConditionComponent']
                                           else
                                             Array.wrap(measure_condition['measureConditionComponent'])
                                           end

          condition_component_attributes.each do |condition_component|
            next unless condition_component.is_a?(Hash)

            measure_condition_components.push({
              measure_condition_sid: measure_condition['sid'],
              duty_expression_id: condition_component.dig('dutyExpression', 'dutyExpressionId'),
              duty_amount: condition_component['dutyAmount'],
              monetary_unit_code: condition_component.dig('monetaryUnit', 'monetaryUnitCode'),
              measurement_unit_code: condition_component.dig('measurementUnit', 'measurementUnitCode'),
              measurement_unit_qualifier_code: condition_component.dig('measurementUnitQualifier', 'measurementUnitQualifierCode'),
              operation: condition_component.dig('metainfo', 'opType'),
              operation_date: condition_component.dig('metainfo', 'transactionDate'),
              filename: file,
            })
          end
        end

        ga_attributes = if attributes.dig('Measure', 'measureExcludedGeographicalArea').is_a?(Array)
                          attributes.dig('Measure', 'measureExcludedGeographicalArea')
                        else
                          Array.wrap(attributes.dig('Measure', 'measureExcludedGeographicalArea'))
                        end

        ga_attributes.each do |ga|
          next unless ga.is_a?(Hash)

          geographical_areas.push({
            measure_sid: attributes.dig('Measure', 'sid'),
            excluded_geographical_area: ga.dig('geographicalArea', 'geographicalAreaId'),
            geographical_area_sid: ga.dig('geographicalArea', 'sid'),
            operation: ga.dig('metainfo', 'opType'),
            operation_date: ga.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end

        stop_attributes = if attributes.dig('Measure', 'measurePartialTemporaryStop').is_a?(Array)
                            attributes.dig('Measure', 'measurePartialTemporaryStop')
                          else
                            Array.wrap(attributes.dig('Measure', 'measurePartialTemporaryStop'))
                          end

        stop_attributes.each do |stops|
          next unless stops.is_a?(Hash)

          partial_stops.push({
            measure_sid: attributes.dig('Measure', 'sid'),
            partial_temporary_stop_regulation_id: stops['partialTemporaryStopRegulationId'],
            partial_temporary_stop_regulation_officialjournal_number: stops['partialTemporaryStopRegulationOfficialjournalNumber'],
            partial_temporary_stop_regulation_officialjournal_page: stops['partialTemporaryStopRegulationOfficialjournalPage'],
            abrogation_regulation_id: stops['abrogationRegulationId'],
            abrogation_regulation_officialjournal_number: stops['abrogationRegulationOfficialjournalNumber'],
            abrogation_regulation_officialjournal_page: stops['abrogationRegulationOfficialjournalPage'],
            validity_start_date: stops['validityStartDate'],
            validity_end_date: stops['validityEndDate'],
            operation: stops.dig('metainfo', 'opType'),
            operation_date: stops.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end
      end

      Object.const_get('Measure::Operation').multi_insert(measures)
      Object.const_get('MeasureComponent::Operation').multi_insert(measure_components)
      Object.const_get('MeasureCondition::Operation').multi_insert(measure_conditions)
      Object.const_get('MeasureConditionComponent::Operation').multi_insert(measure_condition_components)
      Object.const_get('MeasureExcludedGeographicalArea::Operation').multi_insert(geographical_areas)
      Object.const_get('MeasurePartialTemporaryStop::Operation').multi_insert(partial_stops)
      Object.const_get('FootnoteAssociationMeasure::Operation').multi_insert(footnotes)
    end
  end
end
