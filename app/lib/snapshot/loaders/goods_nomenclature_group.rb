module Loaders
  class GoodsNomenclatureGroup < Base
    def self.load(file, batch)
      gns = []
      descriptions = []

      batch.each do |attributes|
        gns.push({
                             goods_nomenclature_group_type: attributes.dig('GoodsNomenclatureGroup', 'goodsNomenclatureGroupType'),
                             goods_nomenclature_group_id: attributes.dig('GoodsNomenclatureGroup', 'goodsNomenclatureGroupId'),
                             nomenclature_group_facility_code: attributes.dig('GoodsNomenclatureGroup', 'nomenclatureGroupFacilityCode'),
                             validity_start_date: attributes.dig('GoodsNomenclatureGroup', 'validityStartDate'),
                             validity_end_date: attributes.dig('GoodsNomenclatureGroup', 'validityEndDate'),
                             operation: attributes.dig('GoodsNomenclatureGroup', 'metainfo', 'opType'),
                             operation_date: attributes.dig('GoodsNomenclatureGroup', 'metainfo', 'transactionDate'),
                             filename: file,
                           })

        descriptions.push({
                            goods_nomenclature_group_type: attributes.dig('GoodsNomenclatureGroup', 'goodsNomenclatureGroupType'),
                            goods_nomenclature_group_id: attributes.dig('GoodsNomenclatureGroup', 'goodsNomenclatureGroupId'),
                            language_id: attributes.dig('GoodsNomenclatureGroup', 'measureTypeDescription', 'language', 'languageId'),
                            description: attributes.dig('GoodsNomenclatureGroup', 'measureTypeDescription', 'description'),
                            operation: attributes.dig('GoodsNomenclatureGroup', 'measureTypeDescription', 'metainfo', 'opType'),
                            operation_date: attributes.dig('GoodsNomenclatureGroup', 'measureTypeDescription', 'metainfo', 'transactionDate'),
                            filename: file,
                          })
      end

      Object.const_get('GoodsNomenclatureGroup::Operation').multi_insert(gns)
      Object.const_get('GoodsNomenclatureGroupDescription::Operation').multi_insert(descriptions)
    end
  end
end
