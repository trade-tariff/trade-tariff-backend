class CdsImporter
  class EntityMapper
    class GoodsNomenclatureDescriptionMapper < BaseMapper
      self.entity_class = 'GoodsNomenclatureDescription'.freeze

      self.mapping_root = 'GoodsNomenclature'.freeze

      self.mapping_path = 'goodsNomenclatureDescriptionPeriod.goodsNomenclatureDescription'.freeze

      self.exclude_mapping = ['metainfo.origin', 'validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'goodsNomenclatureDescriptionPeriod.sid' => :goods_nomenclature_description_period_sid,
        "#{mapping_path}.language.languageId" => :language_id,
        'sid' => :goods_nomenclature_sid,
        'goodsNomenclatureItemId' => :goods_nomenclature_item_id,
        'produclineSuffix' => :productline_suffix,
        "#{mapping_path}.description" => :description,
      ).freeze
    end
  end
end
