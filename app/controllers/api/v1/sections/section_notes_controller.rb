module Api
  module V1
    module Sections
      class SectionNotesController < ApiController
        before_action :authenticate_user!
        skip_before_action :authenticate_user!, only: [:show]

        rescue_from Sequel::RecordNotFound do |exception|
          render json: {}, status: 404
        end

        def show
          @section = section
          @section_note = section.section_note

          raise Sequel::RecordNotFound if @section_note.blank?

          respond_with @section_note
        end

        def create
          section_note = SectionNote.new(section_note_params.merge(section_id: section.id))
          section_note.save(raise_on_failure: false)

          respond_with section_note,
                       location: api_section_section_note_url(section.id)
        end

        def update
          section_note = section.section_note
          section_note.set(section_note_params)
          section_note.save(raise_on_failure: false)

          respond_with section_note
        end

        def destroy
          section_note = section.section_note

          raise Sequel::RecordNotFound if section_note.blank?

          section_note.destroy

          respond_with section_note
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
