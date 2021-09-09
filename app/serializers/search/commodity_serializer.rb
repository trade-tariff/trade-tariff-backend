module Search
  class CommoditySerializer < ::Serializer
    def serializable_hash(_opts = {})
      commodity_attributes = {
        id: goods_nomenclature_sid,
        goods_nomenclature_item_id: goods_nomenclature_item_id,
        producline_suffix: producline_suffix,
        validity_start_date: validity_start_date,
        validity_end_date: validity_end_date,
        description: formatted_description,
        number_indents: number_indents,
        declarable: declarable?,
      }

      if heading.present?
        commodity_attributes[:heading] = {
          goods_nomenclature_sid: heading.goods_nomenclature_sid,
          goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
          producline_suffix: heading.producline_suffix,
          validity_start_date: heading.validity_start_date,
          validity_end_date: heading.validity_end_date,
          description: heading.formatted_description,
          number_indents: heading.number_indents,
        }

        if chapter.present?
          commodity_attributes[:chapter] = {
            goods_nomenclature_sid: chapter.goods_nomenclature_sid,
            goods_nomenclature_item_id: chapter.goods_nomenclature_item_id,
            producline_suffix: chapter.producline_suffix,
            validity_start_date: chapter.validity_start_date,
            validity_end_date: chapter.validity_end_date,
            description: chapter.formatted_description,
            guides: chapter.guides.map do |guide|
              {
                title: guide.title,
                url: guide.url,
              }
            end,
          }

          if section.present?
            commodity_attributes[:section] = {
              numeral: section.numeral,
              title: section.title,
              position: section.position,
            }
          end
        end
      end

      commodity_attributes
    end
  end
end
