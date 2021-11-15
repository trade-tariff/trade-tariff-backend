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
        'description' => :description
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
