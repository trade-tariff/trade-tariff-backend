module Api
  module V3
    class ChaptersController < BaseController
      def show
        chapter = Chapter.actual
          .by_code(chapter_id)
          .eager(:chapter_note, :sections)
          .take
        raise Sequel::RecordNotFound, "Chapter #{chapter_id} not found" if chapter.nil?

        render json: Api::V3::ChapterSerializer.new(chapter).call
      end

      def headings
        chapter = Chapter.actual
          .by_code(chapter_id)
          .eager(headings: :goods_nomenclature_descriptions)
          .take
        raise Sequel::RecordNotFound, "Chapter #{chapter_id} not found" if chapter.nil?

        render json: Api::V3::ChapterSerializer.heading_collection(chapter.headings)
      end

    private

      def chapter_id
        params[:id].to_s.rjust(2, '0')
      end
    end
  end
end
