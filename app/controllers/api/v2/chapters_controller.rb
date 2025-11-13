module Api
  module V2
    class ChaptersController < ApiController
      CACHE_VERSION = 2

      def index
        respond_to do |format|
          format.csv do
            send_data(
              Api::V2::Csv::ChapterSerializer.new(chapters).serialized_csv,
              type: 'text/csv; charset=utf-8; header=present',
              disposition: "attachment; filename=#{TradeTariffBackend.service}-chapters-#{actual_date.iso8601}.csv",
            )
          end

          format.any do
            cache_key = "_chapters-#{actual_date}/v#{CACHE_VERSION}"

            serialized_result = Rails.cache.fetch(cache_key, expires_at: actual_date.end_of_day) do
              Api::V2::Chapters::ChapterListSerializer.new(chapters).serializable_hash.to_json
            end

            render json: serialized_result
          end
        end
      end

      def show
        cache_key = "_chapter-#{chapter_id}-#{actual_date}/v#{CACHE_VERSION}"

        serialized_result = Rails.cache.fetch(cache_key, expires_at: actual_date.end_of_day) do
          presenter = Api::V2::Chapters::ChapterPresenter.new(chapter, chapter_headings)

          options = { is_collection: false }
          options[:include] = %i[section guides headings headings.children]

          Api::V2::Chapters::ChapterSerializer.new(presenter, options).serializable_hash.to_json
        end

        render json: serialized_result
      end

      def changes
        cache_key = "_chapter-#{chapter_id}-#{actual_date}/changes-v#{CACHE_VERSION}"
        options = {}
        options[:include] = [:record, 'record.geographical_area', 'record.measure_type']
        serialized_result = Rails.cache.fetch(cache_key, expires_at: actual_date.end_of_day) do
          changes = chapter.changes.where { |o| o.operation_date <= actual_date }
          change_log = ChangeLog.new(changes)

          Api::V2::Changes::ChangeSerializer.new(change_log.changes, options).serializable_hash.to_json
        end

        render json: serialized_result
      end

      def headings
        respond_to do |format|
          filename = "#{TradeTariffBackend.service}-chapter-#{params[:id]}-headings-#{actual_date.iso8601}.csv"

          format.csv do
            send_data(
              Api::V2::Csv::HeadingSerializer.new(chapter_headings).serialized_csv,
              type: 'text/csv; charset=utf-8; header=present',
              disposition: "attachment; filename=#{filename}",
            )
          end

          format.any { head :not_acceptable }
        end
      end

      private

      def chapter
        Chapter
          .actual
          .non_hidden
          .by_code(chapter_id)
          .take
      end

      def chapters
        Chapter
          .actual
          .non_hidden
          .eager(:chapter_note, :goods_nomenclature_descriptions)
          .all
      end

      def chapter_id
        params[:id]
      end

      def chapter_headings
        chapter
          .headings_dataset
          .eager(:goods_nomenclature_descriptions, :children)
          .all
      end
    end
  end
end
