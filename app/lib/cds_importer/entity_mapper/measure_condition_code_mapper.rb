class CdsImporter
  class EntityMapper
    class MeasureConditionCodeMapper < BaseMapper
      self.entity_class = 'MeasureConditionCode'.freeze

      self.mapping_root = 'MeasureConditionCode'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'conditionCode' => :condition_code,
      ).freeze
    end
  end
end
