class CdsImporter
  class EntityMapper
    class FootnoteMapper < BaseMapper
      self.entity_class = 'Footnote'.freeze

      self.mapping_root = 'Footnote'.freeze

      self.entity_mapping = base_mapping.merge(
        'footnoteId' => :footnote_id,
        'footnoteType.footnoteTypeId' => :footnote_type_id,
      ).freeze

      before_oplog_inserts do |_xml_node, mapper_instance, model_instance|
        if mapper_instance.destroy_operation?
          footnote_id = model_instance.footnote_id
          footnote_type_id = model_instance.footnote_type_id
          filename = mapper_instance.filename

          instrument_cascade_destroy(filename) { FootnoteAssociationAdditionalCode.where(footnote_type_id:, footnote_id:) }
          instrument_cascade_destroy(filename) { FootnoteAssociationGoodsNomenclature.where(footnote_type: footnote_type_id, footnote_id:) }

          instrument_cascade_destroy(filename) { FootnoteAssociationMeasure.where(footnote_type_id:, footnote_id:) }
          instrument_cascade_destroy(filename) { FootnoteAssociationMeursingHeading.where(footnote_type: footnote_type_id, footnote_id:) }
          instrument_cascade_destroy(filename) { FootnoteDescription.where(footnote_type_id:, footnote_id:) }
          instrument_cascade_destroy(filename) { FootnoteDescriptionPeriod.where(footnote_type_id:, footnote_id:) }
        end
      end

      delete_missing_entities FootnoteDescriptionPeriodMapper
    end
  end
end
