class CdsImporter
  class EntityMapper
    class GoodsNomenclatureGroupMapper < BaseMapper
      self.entity_class = 'GoodsNomenclatureGroup'.freeze

      self.mapping_root = 'GoodsNomenclatureGroup'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'goodsNomenclatureGroupType' => :goods_nomenclature_group_type,
        'goodsNomenclatureGroupId' => :goods_nomenclature_group_id,
        'nomenclatureGroupFacilityCode' => :nomenclature_group_facility_code
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
