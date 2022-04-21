module Api
  module V2
    class SectionsController < ApiController
      def index
        @sections = Section
          .eager({ chapters: [:chapter_note] }, :section_note)
          .all

        respond_to do |format|
          format.csv do
            send_data(
              Api::V2::Csv::SectionSerializer.new(@sections).serialized_csv,
              type: 'text/csv; charset=utf-8; header=present',
              disposition: "attachment; filename=sections-#{actual_date.iso8601}.csv",
            )
          end

          format.all { render json: Api::V2::Sections::SectionListSerializer.new(@sections).serializable_hash }
        end
      end

      def show
        # id is a position
        @section = Section.where(position: params[:id])
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
              disposition: "attachment; filename=sections-#{params[:id]}-chapters-#{actual_date.iso8601}.csv",
            )
          end

          format.any do
            render json: Api::V2::Chapters::ChapterListSerializer.new(chapters).serializable_hash
          end
        end
      end
    end
  end
end
