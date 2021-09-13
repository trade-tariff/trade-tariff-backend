module Search
  class ChapterSerializer < ::Serializer
    def serializable_hash(_opts = {})
      chapter_attributes = {
        id: goods_nomenclature_sid,
        goods_nomenclature_item_id: goods_nomenclature_item_id,
        producline_suffix: producline_suffix,
        validity_start_date: validity_start_date,
        validity_end_date: validity_end_date,
        description: formatted_description,
        guides: guides.map do |guide|
          {
            title: guide.title,
            url: guide.url,
          }
        end,
        declarable: false,
      }

      if section.present?
        chapter_attributes[:section] = {
          numeral: section.numeral,
          title: section.title,
          position: section.position,
        }
      end

      chapter_attributes
    end
  end
end
