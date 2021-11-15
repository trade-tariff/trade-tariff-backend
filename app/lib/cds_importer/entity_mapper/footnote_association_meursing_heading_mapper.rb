#
# MeursingTablePlan -> meursingHeading -> footnoteAssociationMeursingHeading
#

class CdsImporter
  class EntityMapper
    class FootnoteAssociationMeursingHeadingMapper < BaseMapper
      self.entity_class = 'FootnoteAssociationMeursingHeading'.freeze

      self.mapping_root = 'MeursingTablePlan'.freeze

      self.mapping_path = 'meursingHeading.footnoteAssociationMeursingHeading'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'meursingTablePlanId' => :meursing_table_plan_id,
        'meursingHeading.meursingHeadingNumber' => :meursing_heading_number,
        'meursingHeading.rowColumnCode' => :row_column_code,
        "#{mapping_path}.footnote.footnoteType.footnoteTypeId" => :footnote_type,
        "#{mapping_path}.footnote.footnoteId" => :footnote_id
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
