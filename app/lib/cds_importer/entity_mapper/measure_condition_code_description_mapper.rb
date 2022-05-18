class CdsImporter
  class EntityMapper
    class MeasureConditionCodeDescriptionMapper < BaseMapper
      self.entity_class = 'MeasureConditionCodeDescription'.freeze

      self.mapping_root = 'MeasureConditionCode'.freeze

      self.mapping_path = 'measureConditionCodeDescription'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate', 'metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'conditionCode' => :condition_code,
        "#{mapping_path}.language.languageId" => :language_id,
        "#{mapping_path}.description" => :description,
      ).freeze
    end
  end
end
