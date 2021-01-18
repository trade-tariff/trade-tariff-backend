class CdsImporter
  class EntityMapper
    class MeasureTypeSeriesMapper < BaseMapper
      self.entity_class = 'MeasureTypeSeries'.freeze

      self.mapping_root = 'MeasureTypeSeries'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'measureTypeSeriesId' => :measure_type_series_id,
        'measureTypeCombination' => :measure_type_combination
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
