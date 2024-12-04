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
        "#{mapping_path}.footnote.footnoteType.footnoteTypeId" => :footnote_type,
      ).freeze
    end
  end
end
