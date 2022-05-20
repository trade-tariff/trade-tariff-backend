class CdsImporter
  class EntityMapper
    class FootnoteMapper < BaseMapper
      self.entity_class = 'Footnote'.freeze

      self.mapping_root = 'Footnote'.freeze

      self.entity_mapping = base_mapping.merge(
        'footnoteId' => :footnote_id,
        'footnoteType.footnoteTypeId' => :footnote_type_id,
      ).freeze

      before_oplog_inserts do |xml_node, mapper_instance|
        if mapper_instance.destroy_operation?
          footnote_id = xml_node['footnoteId']
          footnote_type_id = xml_node.dig('footnoteType', 'footnoteTypeId')

          FootnoteAssociationAdditionalCode.where(footnote_type_id:, footnote_id:).destroy
          FootnoteAssociationGoodsNomenclature.where(footnote_type: footnote_type_id, footnote_id:).destroy
          FootnoteAssociationMeasure.where(footnote_type_id:, footnote_id:).destroy
          FootnoteAssociationMeursingHeading.where(footnote_type: footnote_type_id, footnote_id:).destroy
          FootnoteDescription.where(footnote_type_id:, footnote_id:).destroy
          FootnoteDescriptionPeriod.where(footnote_type_id:, footnote_id:).destroy
        end
      end
    end
  end
end
