class CdsImporter
  class EntityMapper
    class LanguageDescriptionMapper < BaseMapper
      self.entity_class = 'LanguageDescription'.freeze

      self.mapping_root = 'Language'.freeze

      self.mapping_path = 'languageDescription'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate', 'metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        "#{mapping_path}.language" => :language_code_id,
        'languageId' => :language_id,
        "#{mapping_path}.description" => :description
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
