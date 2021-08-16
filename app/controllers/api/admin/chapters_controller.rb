module Api
  module Admin
    class ChaptersController < ApiController
      before_action :find_chapter, only: [:show]

      def index
        @chapters = Chapter.eager(:chapter_note).all

        render json: Api::Admin::Chapters::ChapterListSerializer.new(@chapters).serializable_hash
      end

      def show
        options = { is_collection: false }
        options[:include] = %i[chapter_note headings section]

        render json: Api::Admin::Chapters::ChapterSerializer.new(@chapter, options).serializable_hash
      end

      private

      def find_chapter
        @chapter = Chapter.actual.where(goods_nomenclature_item_id: chapter_id).take

        raise Sequel::RecordNotFound if @chapter.goods_nomenclature_item_id.in? HiddenGoodsNomenclature.codes
      end

      def chapter_id
        "#{params[:id]}00000000"
      end
    end
  end
end
