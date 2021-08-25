module Search
  class HeadingSerializer < ::Serializer
    def serializable_hash(_opts = {})
      heading_attributes = {
        id: goods_nomenclature_sid,
        goods_nomenclature_item_id: goods_nomenclature_item_id,
        producline_suffix: producline_suffix,
        validity_start_date: validity_start_date,
        validity_end_date: validity_end_date,
        description: formatted_description,
        number_indents: number_indents,
      }

      if chapter.present?
        heading_attributes[:chapter] = {
          goods_nomenclature_sid: chapter.goods_nomenclature_sid,
          goods_nomenclature_item_id: chapter.goods_nomenclature_item_id,
          producline_suffix: chapter.producline_suffix,
          validity_start_date: chapter.validity_start_date,
          validity_end_date: chapter.validity_end_date,
          description: chapter.formatted_description,
          guides: chapter.guides.map do |guide|
            {
              title: guide.title,
              url: guide.url
            }
          end
        }

        if section.present?
          heading_attributes[:section] = {
            numeral: section.numeral,
            title: section.title,
            position: section.position
          }
        end
      end

      heading_attributes
    end
  end
end
