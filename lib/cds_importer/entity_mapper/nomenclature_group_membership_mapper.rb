#
# GoodsNomenclature -> nomenclatureGroupMembership
#

class CdsImporter
  class EntityMapper
    class NomenclatureGroupMembershipMapper < BaseMapper
      self.entity_class = 'NomenclatureGroupMembership'.freeze

      self.mapping_root = 'GoodsNomenclature'.freeze

      self.mapping_path = 'nomenclatureGroupMembership'.freeze

      self.exclude_mapping = ['metainfo.origin'].freeze

      self.entity_mapping = base_mapping.merge(
        'sid' => :goods_nomenclature_sid,
        'produclineSuffix' => :productline_suffix,
        'goodsNomenclatureItemId' => :goods_nomenclature_item_id,
        "#{mapping_path}.goodsNomenclatureGroup.goodsNomenclatureGroupId" => :goods_nomenclature_group_id,
        "#{mapping_path}.goodsNomenclatureGroup.goodsNomenclatureGroupType" => :goods_nomenclature_group_type
      ).freeze

      self.entity_mapping_key_as_array = mapping_with_key_as_array.freeze

      self.entity_mapping_keys_to_parse = mapping_keys_to_parse.freeze
    end
  end
end
