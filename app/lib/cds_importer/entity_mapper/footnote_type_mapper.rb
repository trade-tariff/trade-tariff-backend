class CdsImporter
  class EntityMapper
    class FootnoteTypeMapper < BaseMapper
      self.entity_class = 'FootnoteType'.freeze

      self.mapping_root = 'FootnoteType'.freeze

      self.entity_mapping = base_mapping.merge(
        'footnoteTypeId' => :footnote_type_id,
        'applicationCode' => :application_code,
      ).freeze
    end
  end
end
