class CdsImporter
  class EntityMapper
    class FootnoteTypeDescriptionMapper < BaseMapper
      self.entity_class = 'FootnoteTypeDescription'.freeze

      self.mapping_root = 'FootnoteType'.freeze

      self.mapping_path = 'footnoteTypeDescription'.freeze

      self.exclude_mapping = %w[validityStartDate validityEndDate].freeze

      self.entity_mapping = base_mapping.merge(
        'footnoteTypeId' => :footnote_type_id,
        "#{mapping_path}.language.languageId" => :language_id,
        "#{mapping_path}.description" => :description,
      ).freeze
    end
  end
end
