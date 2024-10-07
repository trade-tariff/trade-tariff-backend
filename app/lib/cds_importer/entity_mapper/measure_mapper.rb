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
    end
  end
end
