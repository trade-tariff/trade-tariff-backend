class CdsImporter
  class EntityMapper
    class QuotaDefinitionMapper < BaseMapper
      self.entity_class = 'QuotaDefinition'.freeze

      self.mapping_root = 'QuotaDefinition'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :quota_definition_sid,
        'quotaOrderNumber.sid' => :quota_order_number_sid,
        'quotaOrderNumber.quotaOrderNumberId' => :quota_order_number_id,
        'volume' => :volume,
        'initialVolume' => :initial_volume,
        'maximumPrecision' => :maximum_precision,
        'criticalState' => :critical_state,
        'criticalThreshold' => :critical_threshold,
        'monetaryUnit.monetaryUnitCode' => :monetary_unit_code,
        'measurementUnit.measurementUnitCode' => :measurement_unit_code,
        'measurementUnitQualifier.measurementUnitQualifierCode' => :measurement_unit_qualifier_code,
        'description' => :description,
      ).freeze

      before_oplog_inserts do |xml_node|
        QuotaClosedAndTransferredEvent.operation_klass.where(quota_definition_sid: xml_node['sid']).delete
      end
    end
  end
end
