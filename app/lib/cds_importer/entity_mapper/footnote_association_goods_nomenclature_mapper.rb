#
# FootnoteAssociationGoodsNomenclature is nested in to GoodsNomenclature.
#

class CdsImporter
  class EntityMapper
    class FootnoteAssociationGoodsNomenclatureMapper < BaseMapper
      self.entity_class = 'FootnoteAssociationGoodsNomenclature'.freeze

      self.mapping_root = 'GoodsNomenclature'.freeze

      self.mapping_path = 'footnoteAssociationGoodsNomenclature'.freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :goods_nomenclature_sid,
        'produclineSuffix' => :productline_suffix,
        'goodsNomenclatureItemId' => :goods_nomenclature_item_id,
        "#{mapping_path}.footnote.footnoteId" => :footnote_id,
        "#{mapping_path}.footnote.footnoteType.footnoteTypeId" => :footnote_type
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
