class CdsImporter
  class EntityMapper
    class FootnoteAssociationAdditionalCodeMapper < BaseMapper
      self.entity_class = 'FootnoteAssociationAdditionalCode'.freeze

      self.mapping_root = 'AdditionalCode'.freeze

      self.mapping_path = 'footnoteAssociationAdditionalCode'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :additional_code_sid,
        'additionalCodeType.additionalCodeTypeId' => :additional_code_type_id,
        'additionalCodeCode' => :additional_code,
        "#{mapping_path}.footnote.footnoteType.footnoteTypeId" => :footnote_type_id,
        "#{mapping_path}.footnote.footnoteId" => :footnote_id,
      ).freeze
    end
  end
end
