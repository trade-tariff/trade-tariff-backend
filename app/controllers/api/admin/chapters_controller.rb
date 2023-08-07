module Api
  module Admin
    class ChaptersController < AdminController
      def index
        @chapters = Chapter.eager(:chapter_note).all

        render json: Api::Admin::Chapters::ChapterListSerializer.new(@chapters).serializable_hash
      end

      def show
        options = { is_collection: false }
        options[:include] = %i[chapter_note headings section]

        render json: Api::Admin::Chapters::ChapterSerializer.new(chapter, options).serializable_hash
      end

      private

      def chapter
        @chapter = Chapter
          .actual
          .non_hidden
          .by_code(params[:id])
          .take
      end
    end
  end
end
