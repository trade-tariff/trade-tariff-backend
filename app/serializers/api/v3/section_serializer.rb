module Api
  module V3
    class SectionSerializer
      def initialize(section)
        @section = section
      end

      def call
        {
          id: @section.id,
          numeral: @section.numeral,
          title: @section.title,
          position: @section.position,
          chapter_from: @section.chapter_from,
          chapter_to: @section.chapter_to,
          section_note: @section.section_note&.content,
        }
      end

      def self.collection(sections)
        list = sections.map { |s| new(s).call }
        { data: list, meta: { total: list.size } }
      end

      def self.chapter_collection(chapters)
        list = chapters.map do |c|
          {
            goods_nomenclature_sid: c.goods_nomenclature_sid,
            goods_nomenclature_item_id: c.goods_nomenclature_item_id,
            description: c.description,
            formatted_description: c.formatted_description,
            validity_start_date: c.validity_start_date,
            validity_end_date: c.validity_end_date,
          }
        end
        { data: list, meta: { total: list.size } }
      end
    end
  end
end
