class CdsImporter
  class EntityMapper
    class MeasureTypeMapper < BaseMapper
      self.entity_class = 'MeasureType'.freeze

      self.mapping_root = 'MeasureType'.freeze

      self.entity_mapping = base_mapping.merge(
        'measureTypeId' => :measure_type_id,
        'tradeMovementCode' => :trade_movement_code,
        'priorityCode' => :priority_code,
        'measureComponentApplicableCode' => :measure_component_applicable_code,
        'originDestCode' => :origin_dest_code,
        'orderNumberCaptureCode' => :order_number_capture_code,
        'measureExplosionLevel' => :measure_explosion_level,
        'measureTypeSeries.measureTypeSeriesId' => :measure_type_series_id
        # measure_type_acronym will be skipped
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
