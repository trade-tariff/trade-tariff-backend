class CdsImporter
  class EntityMapper
    class MeasureTypeSeriesMapper < BaseMapper
      self.entity_class = 'MeasureTypeSeries'.freeze

      self.mapping_root = 'MeasureTypeSeries'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'measureTypeSeriesId' => :measure_type_series_id,
        'measureTypeCombination' => :measure_type_combination,
      ).freeze
    end
  end
end
