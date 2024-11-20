class CdsImporter
  class EntityMapper
    class FootnoteMapper < BaseMapper
      self.entity_class = 'Footnote'.freeze

      self.mapping_root = 'Footnote'.freeze

      self.entity_mapping = base_mapping.merge(
        'footnoteId' => :footnote_id,
        'footnoteType.footnoteTypeId' => :footnote_type_id,
      ).freeze
    end
  end
end
