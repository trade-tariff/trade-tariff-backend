class CdsImporter
  class EntityMapper
    class GoodsNomenclatureOriginMapper < BaseMapper
      self.entity_class = 'GoodsNomenclatureOrigin'.freeze

      self.mapping_root = 'GoodsNomenclature'.freeze

      self.mapping_path = 'goodsNomenclatureOrigin'.freeze

      self.exclude_mapping = ['metainfo.origin', 'validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :goods_nomenclature_sid,
        "#{mapping_path}.derivedGoodsNomenclatureItemId" => :derived_goods_nomenclature_item_id,
        "#{mapping_path}.derivedProductlineSuffix" => :derived_productline_suffix,
        'goodsNomenclatureItemId' => :goods_nomenclature_item_id,
        'produclineSuffix' => :productline_suffix
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
