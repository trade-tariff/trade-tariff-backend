class CdsImporter
  class EntityMapper
    class GoodsNomenclatureSuccessorMapper < BaseMapper
      self.entity_class = 'GoodsNomenclatureSuccessor'.freeze

      self.mapping_root = 'GoodsNomenclature'.freeze

      self.mapping_path = 'goodsNomenclatureSuccessor'.freeze

      self.exclude_mapping = ['metainfo.origin', 'validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :goods_nomenclature_sid,
        "#{mapping_path}.absorbedGoodsNomenclatureItemId" => :absorbed_goods_nomenclature_item_id,
        "#{mapping_path}.absorbedProductlineSuffix" => :absorbed_productline_suffix,
        'goodsNomenclatureItemId' => :goods_nomenclature_item_id,
        'produclineSuffix' => :productline_suffix,
      ).freeze
    end
  end
end
