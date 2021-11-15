class CdsImporter
  class EntityMapper
    class GoodsNomenclatureGroupDescriptionMapper < BaseMapper
      self.entity_class = 'GoodsNomenclatureGroupDescription'.freeze

      self.mapping_root = 'GoodsNomenclatureGroup'.freeze

      self.mapping_path = 'goodsNomenclatureGroupDescription'.freeze

      self.exclude_mapping = ['metainfo.origin', 'validityStartDate', 'validityEndDate'].freeze

      self.entity_mapping = base_mapping.merge(
        'goodsNomenclatureGroupType' => :goods_nomenclature_group_type,
        'goodsNomenclatureGroupId' => :goods_nomenclature_group_id,
        "#{mapping_path}.language.languageId" => :language_id,
        "#{mapping_path}.description" => :description
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
