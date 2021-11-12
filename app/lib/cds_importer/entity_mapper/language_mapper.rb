class CdsImporter
  class EntityMapper
    class LanguageMapper < BaseMapper
      self.entity_class = 'Language'.freeze

      self.mapping_root = 'Language'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'languageId' => :language_id
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
