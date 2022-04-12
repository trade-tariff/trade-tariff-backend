module Api
  module V2
    class SectionsController < ApiController
      before_action :set_sections, only: :index

      def index
        respond_to do |format|
          format.csv do
            headers['Content-Type'] = 'text/csv'
            headers['Content-Disposition'] = "attachment; filename=#{filename}.csv"

            render content: Api::V2::Csv::SectionSerializer.new(@sections).serialized_csv
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

      private

      def set_sections
        @sections = Section
          .eager({ chapters: [:chapter_note] }, :section_note)
          .all
      end

      def filename
        "sections-#{actual_date.iso8601}.csv"
      end
    end
  end
end
