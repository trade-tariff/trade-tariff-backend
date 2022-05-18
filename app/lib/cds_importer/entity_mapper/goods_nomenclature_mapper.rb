class CdsImporter
  class EntityMapper
    class GoodsNomenclatureMapper < BaseMapper
      self.entity_class = 'GoodsNomenclature'.freeze

      self.mapping_root = 'GoodsNomenclature'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :goods_nomenclature_sid,
        'goodsNomenclatureItemId' => :goods_nomenclature_item_id,
        'produclineSuffix' => :producline_suffix,
        'statisticalIndicator' => :statistical_indicator,
      ).freeze
    end
  end
end
