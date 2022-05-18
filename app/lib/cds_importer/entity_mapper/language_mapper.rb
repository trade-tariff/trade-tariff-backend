class CdsImporter
  class EntityMapper
    class LanguageMapper < BaseMapper
      self.entity_class = 'Language'.freeze

      self.mapping_root = 'Language'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'languageId' => :language_id,
      ).freeze
    end
  end
end
