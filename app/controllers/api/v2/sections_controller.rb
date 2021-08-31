module Api
  module V2
    class SectionsController < ApiController
      def index
        @sections = Section.eager({ chapters: [:chapter_note] }, :section_note).all

        render json: Api::V2::Sections::SectionListSerializer.new(@sections).serializable_hash
      end

      def show
        # id is a position
        @section = Section.where(position: params[:id])
                          .take

        options = { is_collection: false }
        options[:include] = [:chapters, 'chapters.guides']
        render json: Api::V2::Sections::SectionSerializer.new(@section, options).serializable_hash
      end
    end
  end
end
