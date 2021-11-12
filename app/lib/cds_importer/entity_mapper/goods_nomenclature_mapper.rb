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
        'statisticalIndicator' => :statistical_indicator
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
