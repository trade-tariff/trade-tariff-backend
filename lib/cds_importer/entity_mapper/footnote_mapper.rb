class CdsImporter
  class EntityMapper
    class FootnoteMapper < BaseMapper
      self.entity_class = 'Footnote'.freeze

      self.mapping_root = 'Footnote'.freeze

      self.entity_mapping = base_mapping.merge(
        'footnoteId' => :footnote_id,
        'footnoteType.footnoteTypeId' => :footnote_type_id
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
