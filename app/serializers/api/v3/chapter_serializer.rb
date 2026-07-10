module Api
  module V3
    class ChapterSerializer
      def initialize(chapter)
        @chapter = chapter
      end

      def call
        {
          goods_nomenclature_sid: @chapter.goods_nomenclature_sid,
          goods_nomenclature_item_id: @chapter.goods_nomenclature_item_id,
          description: @chapter.description,
          formatted_description: @chapter.formatted_description,
          validity_start_date: @chapter.validity_start_date,
          validity_end_date: @chapter.validity_end_date,
          chapter_note: @chapter.chapter_note&.content,
          section_id: @chapter.section&.id,
        }
      end

      def self.heading_collection(headings)
        list = headings.map do |h|
          {
            goods_nomenclature_sid: h.goods_nomenclature_sid,
            goods_nomenclature_item_id: h.goods_nomenclature_item_id,
            description: h.description,
            formatted_description: h.formatted_description,
            validity_start_date: h.validity_start_date,
            validity_end_date: h.validity_end_date,
          }
        end
        { data: list, meta: { total: list.size } }
      end
    end
  end
end
