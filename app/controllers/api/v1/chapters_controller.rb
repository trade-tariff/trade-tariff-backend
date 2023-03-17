require 'goods_nomenclature_mapper'

module Api
  module V1
    class ChaptersController < ApiController
      def index
        cache_key = "_v1_chapters-#{actual_date}-view"

        serialized_result = Rails.cache.fetch(cache_key, expires_at: actual_date.end_of_day) do
          render_to_string(
            template: 'api/v1/chapters/index',
            formats: [:json],
            locals: { chapters: },
          )
        end

        render json: serialized_result
      end

      def show
        cache_key = "_v1_chapter-#{chapter_id}-#{actual_date}-view"

        serialized_result = Rails.cache.fetch(cache_key, expires_at: actual_date.end_of_day) do
          render_to_string(
            template: 'api/v1/chapters/show',
            formats: [:json],
            locals: { chapter:, headings: root_headings },
          )
        end

        render json: serialized_result
      end

      def changes
        cache_key = "_v1_chapter-#{chapter_id}-#{actual_date}/changes-view"

        serialized_result = Rails.cache.fetch(cache_key, expires_at: actual_date.end_of_day) do
          changes = chapter.changes.where { |o| o.operation_date <= actual_date }
          changes = ChangeLog.new(changes).changes

          render_to_string(
            template: 'api/v1/changes/changes',
            formats: [:json],
            locals: { changes: },
          )
        end

        render json: serialized_result
      end

      private

      def chapter
        @chapter ||= Chapter.actual
          .by_code(chapter_id)
          .non_hidden
          .take
      end

      def chapters
        @chapters ||= Chapter.eager(:chapter_note).all
      end

      def headings
        @headings ||= chapter
          .headings_dataset
          .eager(:goods_nomenclature_descriptions, :goods_nomenclature_indents)
          .all
      end

      def root_headings
        @root_headings ||= GoodsNomenclatureMapper.new(headings).root_entries
      end

      def chapter_id
        params[:id]
      end
    end
  end
end
