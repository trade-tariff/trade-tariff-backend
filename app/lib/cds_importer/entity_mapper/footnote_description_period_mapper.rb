class CdsImporter
  class EntityMapper
    class FootnoteDescriptionPeriodMapper < BaseMapper
      self.entity_class = 'FootnoteDescriptionPeriod'.freeze

      self.mapping_root = 'Footnote'.freeze

      self.mapping_path = 'footnoteDescriptionPeriod'.freeze

      self.entity_mapping = base_mapping.merge(
        "#{mapping_path}.sid" => :footnote_description_period_sid,
        'footnoteType.footnoteTypeId' => :footnote_type_id,
        'footnoteId' => :footnote_id,
      ).freeze
    end
  end
end
