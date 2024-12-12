module Loaders
  class GoodsNomenclature < Base
    def self.load(file, batch)
      gns = []
      footnotes = []
      indents = []
      periods = []
      descriptions = []
      successors = []
      origins = []

      batch.each do |attributes|
        gns.push({
          goods_nomenclature_sid: attributes.dig('GoodsNomenclature', 'sid'),
          goods_nomenclature_item_id: attributes.dig('GoodsNomenclature', 'goodsNomenclatureItemId'),
          producline_suffix: attributes.dig('GoodsNomenclature', 'produclineSuffix'),
          statistical_indicator: attributes.dig('GoodsNomenclature', 'statisticalIndicator'),
          validity_start_date: attributes.dig('GoodsNomenclature', 'validityStartDate'),
          validity_end_date: attributes.dig('GoodsNomenclature', 'validityEndDate'),
          operation: attributes.dig('GoodsNomenclature', 'metainfo', 'opType'),
          operation_date: attributes.dig('GoodsNomenclature', 'metainfo', 'transactionDate'),
          filename: file,
        })

        footnote_attributes = if attributes.dig('GoodsNomenclature', 'footnoteAssociationGoodsNomenclature').is_a?(Array)
                                attributes.dig('GoodsNomenclature', 'footnoteAssociationGoodsNomenclature')
                              else
                                Array.wrap(attributes.dig('GoodsNomenclature', 'footnoteAssociationGoodsNomenclature'))
                              end

        footnote_attributes.each do |footnote|
          next unless footnote.is_a?(Hash)

          footnotes.push({
            goods_nomenclature_sid: attributes.dig('GoodsNomenclature', 'sid'),
            goods_nomenclature_item_id: attributes.dig('GoodsNomenclature', 'goodsNomenclatureItemId'),
            productline_suffix: attributes.dig('GoodsNomenclature', 'produclineSuffix'),
            footnote_id: footnote.dig('footnote', 'footnoteId'),
            footnote_type: footnote.dig('footnote', 'footnoteType', 'footnoteTypeId'),
            validity_start_date: footnote['validityStartDate'],
            validity_end_date: footnote['validityEndDate'],
            operation: footnote.dig('metainfo', 'opType'),
            operation_date: footnote.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end

        indent_attributes = if attributes.dig('GoodsNomenclature', 'goodsNomenclatureIndents').is_a?(Array)
                              attributes.dig('GoodsNomenclature', 'goodsNomenclatureIndents')
                            else
                              Array.wrap(attributes.dig('GoodsNomenclature', 'goodsNomenclatureIndents'))
                            end

        indent_attributes.each do |indent|
          next unless indent.is_a?(Hash)

          indents.push({
            goods_nomenclature_sid: attributes.dig('GoodsNomenclature', 'sid'),
            goods_nomenclature_item_id: attributes.dig('GoodsNomenclature', 'goodsNomenclatureItemId'),
            productline_suffix: attributes.dig('GoodsNomenclature', 'produclineSuffix'),
            goods_nomenclature_indent_sid: indent.dig('footnote', 'footnoteId'),
            number_indents: indent.dig('footnote', 'footnoteType', 'footnoteTypeId'),
            validity_start_date: indent['validityStartDate'],
            validity_end_date: indent['validityEndDate'],
            operation: indent.dig('metainfo', 'opType'),
            operation_date: indent.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end

        period_attributes = if attributes.dig('GoodsNomenclature', 'goodsNomenclatureDescriptionPeriod').is_a?(Array)
                              attributes.dig('GoodsNomenclature', 'goodsNomenclatureDescriptionPeriod')
                            else
                              Array.wrap(attributes.dig('GoodsNomenclature', 'goodsNomenclatureDescriptionPeriod'))
                            end
        period_attributes.each do |period|
          periods.push({
            goods_nomenclature_sid: attributes.dig('GoodsNomenclature', 'sid'),
            goods_nomenclature_item_id: attributes.dig('GoodsNomenclature', 'goodsNomenclatureItemId'),
            productline_suffix: attributes.dig('GoodsNomenclature', 'produclineSuffix'),
            goods_nomenclature_description_period_sid: period['sid'],
            validity_start_date: period['validityStartDate'],
            validity_end_date: period['validityEndDate'],
            operation: period.dig('metainfo', 'opType'),
            operation_date: period.dig('metainfo', 'transactionDate'),
            filename: file,
          })

          description = period['goodsNomenclatureDescription']

          next unless description.present? && description.is_a?(Hash)

          descriptions.push({
            goods_nomenclature_sid: attributes.dig('GoodsNomenclature', 'sid'),
            goods_nomenclature_item_id: attributes.dig('GoodsNomenclature', 'goodsNomenclatureItemId'),
            productline_suffix: attributes.dig('GoodsNomenclature', 'produclineSuffix'),
            goods_nomenclature_description_period_sid: period['sid'],
            language_id: description.dig('language', 'languageId'),
            description: description['description'],
            operation: description.dig('metainfo', 'opType'),
            operation_date: description.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end

        successor_attributes = if attributes.dig('GoodsNomenclature', 'goodsNomenclatureSuccessor').is_a?(Array)
                                 attributes.dig('GoodsNomenclature', 'goodsNomenclatureSuccessor')
                               else
                                 Array.wrap(attributes.dig('GoodsNomenclature', 'goodsNomenclatureSuccessor'))
                               end

        successor_attributes.each do |successor|
          next unless successor.is_a?(Hash)

          successors.push({
            goods_nomenclature_sid: attributes.dig('GoodsNomenclature', 'sid'),
            goods_nomenclature_item_id: attributes.dig('GoodsNomenclature', 'goodsNomenclatureItemId'),
            productline_suffix: attributes.dig('GoodsNomenclature', 'produclineSuffix'),
            absorbed_goods_nomenclature_item_id: successor['absorbedGoodsNomenclatureItemId'],
            absorbed_productline_suffix: successor['absorbedProductlineSuffix'],
            operation: successor.dig('metainfo', 'opType'),
            operation_date: successor.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end

        origin_attributes = if attributes.dig('GoodsNomenclature', 'goodsNomenclatureOrigin').is_a?(Array)
                              attributes.dig('GoodsNomenclature', 'goodsNomenclatureOrigin')
                            else
                              Array.wrap(attributes.dig('GoodsNomenclature', 'goodsNomenclatureOrigin'))
                            end

        origin_attributes.each do |origin|
          next unless origin.is_a?(Hash)

          origins.push({
            goods_nomenclature_sid: attributes.dig('GoodsNomenclature', 'sid'),
            goods_nomenclature_item_id: attributes.dig('GoodsNomenclature', 'goodsNomenclatureItemId'),
            productline_suffix: attributes.dig('GoodsNomenclature', 'produclineSuffix'),
            derived_goods_nomenclature_item_id: origin['derivedGoodsNomenclatureItemId'],
            derived_productline_suffix: origin['derivedProductlineSuffix'],
            operation: origin.dig('metainfo', 'opType'),
            operation_date: origin.dig('metainfo', 'transactionDate'),
            filename: file,
          })
        end
      end

      Object.const_get('GoodsNomenclature::Operation').multi_insert(gns)
      Object.const_get('FootnoteAssociationGoodsNomenclature::Operation').multi_insert(footnotes)
      Object.const_get('GoodsNomenclatureIndent::Operation').multi_insert(indents)
      Object.const_get('GoodsNomenclatureDescriptionPeriod::Operation').multi_insert(periods)
      Object.const_get('GoodsNomenclatureDescription::Operation').multi_insert(descriptions)
      Object.const_get('GoodsNomenclatureSuccessor::Operation').multi_insert(successors)
      Object.const_get('GoodsNomenclatureOrigin::Operation').multi_insert(origins)
    end
  end
end
