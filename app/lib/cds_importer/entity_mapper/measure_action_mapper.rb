class CdsImporter
  class EntityMapper
    class MeasureActionMapper < BaseMapper
      self.entity_class = 'MeasureAction'.freeze

      self.mapping_root = 'MeasureAction'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'actionCode' => :action_code,
      ).freeze
    end
  end
end
