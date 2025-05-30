class CdsImporter
  class EntityMapper
    class MeasureMapper < BaseMapper
      self.entity_class = 'Measure'.freeze

      self.mapping_root = 'Measure'.freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :measure_sid,
        'measureType.measureTypeId' => :measure_type_id,
        'geographicalArea.geographicalAreaId' => :geographical_area_id,
        'geographicalArea.sid' => :geographical_area_sid,
        'goodsNomenclature.goodsNomenclatureItemId' => :goods_nomenclature_item_id,
        'goodsNomenclature.sid' => :goods_nomenclature_sid,
        'measureGeneratingRegulationRole.regulationRoleTypeId' => :measure_generating_regulation_role,
        'measureGeneratingRegulationId' => :measure_generating_regulation_id,
        'justificationRegulationRole.regulationRoleTypeId' => :justification_regulation_role,
        'justificationRegulationId' => :justification_regulation_id,
        'stoppedFlag' => :stopped_flag,
        'ordernumber' => :ordernumber,
        'additionalCode.additionalCodeType.additionalCodeTypeId' => :additional_code_type_id,
        'additionalCode.additionalCodeCode' => :additional_code_id,
        'additionalCode.sid' => :additional_code_sid,
        'reductionIndicator' => :reduction_indicator,
        'exportRefundNomenclature.sid' => :export_refund_nomenclature_sid,
      ).freeze

      self.reportable_entity_mapping = reportable_base_mapping.merge(
        'goodsNomenclature.goodsNomenclatureItemId' => :goods_nomenclature_item_id,
        'additionalCode.additionalCodeType.additionalCodeTypeId' => :additional_code_type_id,
        'measureType.measureTypeId' => :measure_type_id,
        'geographicalArea.geographicalAreaId' => :geographical_area_id,
        'footnoteAssociationMeasure.footnote.footnoteTypeId' => :footnote_type_id,
        'footnoteAssociationMeasure.footnote.footnoteId' => :footnote_id,
        'measureComponent.dutyAmount' => :duty_amount,
        'measureCondition.sid' => :measure_condition_sid,
        'measureCondition.measureAction.actionCode' => :measure_action_code,
        'measureCondition.measureConditionCode' => :measure_condition_code,
      ).freeze

        'sid' => :measure_sid,
      ).freeze

      before_oplog_inserts do |xml_node, _mapper, _model_instance, _expanded_model_values, implicit_deletes_enabled|
        if implicit_deletes_enabled
          MeasureExcludedGeographicalArea.operation_klass.where(
            measure_sid: xml_node['sid'],
          ).delete
        end
      end

      before_oplog_inserts do |xml_node, _mapper, _model_instance, _expanded_model_values, implicit_deletes_enabled|
        if implicit_deletes_enabled
          FootnoteAssociationMeasure.operation_klass.where(
            measure_sid: xml_node['sid'],
          ).delete
        end
      end
    end
  end
end
