module Api
  module V1
    class ChaptersController < ApiController
      before_action :find_chapter, only: %i[show changes]

      def index
        @chapters = Chapter.eager(:chapter_note).all

        respond_with @chapters
      end

      def show
        @headings = GoodsNomenclatureMapper.new(@chapter.headings_dataset
                                                        .eager(:goods_nomenclature_descriptions,
                                                               :goods_nomenclature_indents)
                                                        .all).root_entries

        respond_with @chapter
      end

      def changes
        key = "chapter-#{@chapter.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}/changes"
        @changes = Rails.cache.fetch(key, expires_at: actual_date.end_of_day) do
          ChangeLog.new(@chapter.changes.where do |o|
            o.operation_date <= actual_date
          end)
        end

        render 'api/v1/changes/changes'
      end

      private

      def find_chapter
        @chapter = Chapter.actual
                          .where(goods_nomenclature_item_id: chapter_id)
                          .take

        raise Sequel::RecordNotFound if @chapter.goods_nomenclature_item_id.in? HiddenGoodsNomenclature.codes
      end

      def chapter_id
        "#{params[:id]}00000000"
      end
    end
  end
end
