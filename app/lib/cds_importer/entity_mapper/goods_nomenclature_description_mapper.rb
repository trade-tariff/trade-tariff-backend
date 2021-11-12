#
# There is no collection with GoodsNomenclatureDescription in new xml.
# GoodsNomenclatureDescription is nested in to GoodsNomenclatureDescriptionPeriod.
# GoodsNomenclatureDescriptionPeriod is nested in to GoodsNomenclature.
# We will pass @values for GoodsNomenclatureDescription the same as for GoodsNomenclature.
#

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
        "#{mapping_path}.description" => :description
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
