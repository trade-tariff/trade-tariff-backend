module Api
  module Admin
    class SectionsController < AdminController
      def index
        @sections = Section.eager({ chapters: [:chapter_note] }, :section_note).all

        render json: Api::Admin::Sections::SectionListSerializer.new(@sections).serializable_hash
      end

      def show
        # id is a position
        @section = Section.take(position: params[:id])

        options = { is_collection: false }
        options[:include] = %i[chapters section_note]
        render json: Api::Admin::Sections::SectionSerializer.new(@section, options).serializable_hash
      end
    end
  end
end
