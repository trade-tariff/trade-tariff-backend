class CdsImporter
  class EntityMapper
    class FootnoteTypeMapper < BaseMapper
      self.entity_class = 'FootnoteType'.freeze

      self.mapping_root = 'FootnoteType'.freeze

      self.entity_mapping = base_mapping.merge(
        'footnoteTypeId' => :footnote_type_id,
        'applicationCode' => :application_code
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
