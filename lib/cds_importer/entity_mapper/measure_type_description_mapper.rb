class CdsImporter
  class EntityMapper
    class MeasureTypeDescriptionMapper < BaseMapper
      self.entity_class = 'MeasureTypeDescription'.freeze

      self.mapping_root = 'MeasureType'.freeze

      self.mapping_path = 'measureTypeDescription'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'measureTypeId' => :measure_type_id,
        "#{mapping_path}.language.languageId" => :language_id,
        "#{mapping_path}.description" => :description
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
