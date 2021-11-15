class CdsImporter
  class EntityMapper
    class FootnoteDescriptionMapper < BaseMapper
      self.entity_class = 'FootnoteDescription'.freeze

      self.mapping_root = 'Footnote'.freeze

      self.mapping_path = 'footnoteDescriptionPeriod.footnoteDescription'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'footnoteDescriptionPeriod.sid' => :footnote_description_period_sid,
        'footnoteType.footnoteTypeId' => :footnote_type_id,
        'footnoteId' => :footnote_id,
        "#{mapping_path}.language.languageId" => :language_id,
        "#{mapping_path}.description" => :description
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
