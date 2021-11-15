#
# FootnoteAssociationMeasure is nested in to Measure.
#

class CdsImporter
  class EntityMapper
    class FootnoteAssociationMeasureMapper < BaseMapper
      self.entity_class = 'FootnoteAssociationMeasure'.freeze

      self.mapping_root = 'Measure'.freeze

      self.mapping_path = 'footnoteAssociationMeasure'.freeze

      self.exclude_mapping = ['validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :measure_sid,
        "#{mapping_path}.footnote.footnoteType.footnoteTypeId" => :footnote_type_id,
        "#{mapping_path}.footnote.footnoteId" => :footnote_id
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
