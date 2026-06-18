module Api
  module V2
    class ChaptersController < ApiController
      include SearchResultTracking

      before_action :track_result_selected, only: :show

      CACHE_VERSION = 2
      SHOW_DEFAULT_INCLUDE = %i[section guides headings headings.children].freeze

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
            cache_key = "#{cache_key}/jsonapi-#{jsonapi_options_cache_suffix}" if jsonapi_options_requested?

            serialized_result = Rails.cache.fetch(cache_key, expires_at: actual_date.end_of_day) do
              Api::V2::Chapters::ChapterListSerializer.new(chapters, jsonapi_serializer_options).serializable_hash.to_json
            end

            render json: serialized_result
          end
        end
      end

      def show
        cache_key = "_chapter-#{chapter_id}-#{actual_date}/v#{CACHE_VERSION}"
        default_include = SHOW_DEFAULT_INCLUDE
        cache_key = "#{cache_key}/jsonapi-#{jsonapi_options_cache_suffix(default_include:)}" if jsonapi_options_requested?

        serialized_result = Rails.cache.fetch(cache_key, expires_at: actual_date.end_of_day) do
          presenter = Api::V2::Chapters::ChapterPresenter.new(chapter, requested_chapter_headings)

          options = jsonapi_serializer_options(is_collection: false, default_include:)

          Api::V2::Chapters::ChapterSerializer.new(presenter, options).serializable_hash.to_json
        end

        render json: serialized_result
      end

      def changes
        cache_key = "_chapter-#{chapter_id}-#{actual_date}/changes-v#{CACHE_VERSION}"
        default_include = [:record, 'record.geographical_area', 'record.measure_type']
        cache_key = "#{cache_key}/jsonapi-#{jsonapi_options_cache_suffix(default_include:)}" if jsonapi_options_requested?
        options = jsonapi_serializer_options(default_include:)
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
        scope = Chapter
          .actual
          .non_hidden
          .by_code(chapter_id)

        eager_loads = chapter_eager_loads
        scope = scope.eager(*eager_loads) if eager_loads.any?
        scope.take
      end

      def chapters
        scope = Chapter
          .actual
          .non_hidden

        scope = scope.eager(:goods_nomenclature_descriptions) if chapter_description_fields_requested?
        scope.all
      end

      def chapter_note_eager_load
        TradeTariffBackend.promote_customs_tariff_notes? ? :customs_tariff_chapter_note : :chapter_note
      end

      def section_note_eager_load
        TradeTariffBackend.promote_customs_tariff_notes? ? :customs_tariff_section_note : :section_note
      end

      def chapter_eager_loads
        [].tap do |eager_loads|
          eager_loads << chapter_note_eager_load if jsonapi_field_requested?(:chapter, :chapter_note)
          eager_loads << section_eager_load if chapter_section_data_requested?
        end
      end

      def chapter_description_fields_requested?
        %i[description description_plain formatted_description].any? do |field|
          jsonapi_field_requested?(:chapter, field)
        end
      end

      def chapter_section_data_requested?
        jsonapi_field_requested?(:chapter, :section_id) ||
          jsonapi_relationship_requested?(:chapter, :section, default_include: SHOW_DEFAULT_INCLUDE)
      end

      def section_eager_load
        return :sections unless jsonapi_field_requested?(:section, :section_note)

        { sections: [section_note_eager_load] }
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

      def requested_chapter_headings
        return [] unless jsonapi_relationship_requested?(:chapter, :headings, default_include: %i[headings headings.children])

        chapter_headings
      end
    end
  end
end
