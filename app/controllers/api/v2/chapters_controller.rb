require 'goods_nomenclature_mapper'

module Api
  module V2
    class ChaptersController < ApiController
      CACHE_VERSION = 1
      before_action :find_chapter, only: %i[show changes headings]

      def index
        @chapters = Chapter.eager(:chapter_note, :goods_nomenclature_descriptions).all
        respond_to do |format|
          format.csv do
            send_data(
              Api::V2::Csv::ChapterSerializer.new(@chapters).serialized_csv,
              type: 'text/csv; charset=utf-8; header=present',
              disposition: "attachment; filename=#{TradeTariffBackend.service}-chapters-#{actual_date.iso8601}.csv",
            )
          end

          format.any { render json: Api::V2::Chapters::ChapterListSerializer.new(@chapters).serializable_hash }
        end
      end

      def show
        chapter_id = params[:id]
        cache_key = "_chapter-v#{CACHE_VERSION}-#{chapter_id}-#{actual_date}"

        Rails.cache.fetch(cache_key, expires_at: actual_date.end_of_day) do
          root_headings = GoodsNomenclatureMapper.new(chapter.headings_dataset
            .eager(:goods_nomenclature_descriptions,
                   :goods_nomenclature_indents)
            .all).root_entries

          options = { is_collection: false }
          options[:include] = [:section, :guides, :headings, 'headings.children']
          presenter = Api::V2::Chapters::ChapterPresenter.new(chapter, root_headings)
          render json: Api::V2::Chapters::ChapterSerializer.new(presenter, options).serializable_hash
        end
      end

      def changes
        key = "chapter-#{@chapter.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}/changes"
        @changes = Rails.cache.fetch(key, expires_at: actual_date.end_of_day) do
          ChangeLog.new(@chapter.changes.where do |o|
            o.operation_date <= actual_date
          end)
        end

        options = {}
        options[:include] = [:record, 'record.geographical_area', 'record.measure_type']
        render json: Api::V2::Changes::ChangeSerializer.new(@changes.changes, options).serializable_hash
      end

      def headings
        chapter_headings = chapter.headings

        respond_to do |format|
          filename = "#{TradeTariffBackend.service}-chapter-#{params[:id]}-headings-#{actual_date.iso8601}.csv"

          format.csv do
            send_data(
              Api::V2::Csv::HeadingSerializer.new(chapter_headings).serialized_csv,
              type: 'text/csv; charset=utf-8; header=present',
              disposition: "attachment; filename=#{filename}",
            )
          end
        end
      end

      private

      attr_reader :chapter

      def find_chapter
        @chapter = Chapter.actual
                          .where(goods_nomenclature_item_id: chapter_id)
                          .take

        raise Sequel::RecordNotFound if @chapter.goods_nomenclature_item_id.in? HiddenGoodsNomenclature.codes
      end

      def chapter_id
        "#{params[:id]}00000000"
      end

      def chapter_cache_key; end
    end
  end
end
