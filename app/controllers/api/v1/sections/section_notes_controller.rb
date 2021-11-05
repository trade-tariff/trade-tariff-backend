module Api
  module V1
    module Sections
      class SectionNotesController < ApiController
        rescue_from Sequel::RecordNotFound do |_exception|
          render json: {}, status: :not_found
        end

        def show
          @section = section
          @section_note = section.section_note

          raise Sequel::RecordNotFound if @section_note.blank?

          respond_with @section_note
        end

        private

        def section_note_params
          params.require(:section_note).permit(:content)
        end

        def section
          @section ||= Section.find(id: params[:section_id])
        end
      end
    end
  end
end
