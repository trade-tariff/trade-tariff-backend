module Api
  module V2
    class SectionsController < ApiController
      def index
        @sections = sections_dataset.all

        respond_to do |format|
          format.csv do
            send_data(
              Api::V2::Csv::SectionSerializer.new(@sections).serialized_csv,
              type: 'text/csv; charset=utf-8; header=present',
              disposition: "attachment; filename=#{TradeTariffBackend.service}-sections-#{actual_date.iso8601}.csv",
            )
          end

          format.all { render json: Api::V2::Sections::SectionListSerializer.new(@sections).serializable_hash }
        end
      end

      def show
        return head :bad_request unless params[:id].to_s.match?(/\A\d+\z/)

        @section = sections_dataset
          .where(position: params[:id].to_i)
          .take

        options = { is_collection: false }
        options[:include] = [:chapters, 'chapters.guides']
        render json: Api::V2::Sections::SectionSerializer.new(@section, options).serializable_hash
      end

      def chapters
        chapters = Section.where(position: params[:id])
          .take
          .chapters

        respond_to do |format|
          format.csv do
            send_data(
              Api::V2::Csv::ChapterSerializer.new(chapters).serialized_csv,
              type: 'text/csv; charset=utf-8; header=present',
              disposition: "attachment; filename=#{TradeTariffBackend.service}-sections-#{params[:id]}-chapters-#{actual_date.iso8601}.csv",
            )
          end

          format.any do
            render json: Api::V2::Chapters::ChapterListSerializer.new(chapters).serializable_hash
          end
        end
      end

      private

      def chapter_note_eager_load
        TradeTariffBackend.promote_customs_tariff_notes? ? :customs_tariff_chapter_note : :chapter_note
      end

      def section_note_eager_load
        TradeTariffBackend.promote_customs_tariff_notes? ? :customs_tariff_section_note : :section_note
      end

      def sections_dataset
        eager_loads = []
        eager_loads << { chapters: [chapter_note_eager_load] } if section_chapter_fields_requested?
        eager_loads << section_note_eager_load if jsonapi_field_requested?(:section, :section_note)

        return Section if eager_loads.empty?

        Section.eager(*eager_loads)
      end

      def section_chapter_fields_requested?
        %i[chapters chapter_from chapter_to].any? do |field|
          jsonapi_field_requested?(:section, field)
        end
      end
    end
  end
end
