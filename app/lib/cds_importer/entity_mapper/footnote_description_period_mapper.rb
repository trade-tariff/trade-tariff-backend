class CdsImporter
  class EntityMapper
    class FootnoteDescriptionPeriodMapper < BaseMapper
      self.entity_class = 'FootnoteDescriptionPeriod'.freeze

      self.mapping_root = 'Footnote'.freeze

      self.mapping_path = 'footnoteDescriptionPeriod'.freeze

      self.entity_mapping = base_mapping.merge(
        "#{mapping_path}.sid" => :footnote_description_period_sid,
        'footnoteType.footnoteTypeId' => :footnote_type_id,
        'footnoteId' => :footnote_id
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
