module Api
  module Admin
    module Chapters
      class ChapterNotesController < AdminController
        def show
          chapter_note = chapter.chapter_note

          raise Sequel::RecordNotFound if chapter_note.blank?

          render json: Api::Admin::Chapters::ChapterNoteSerializer.new(chapter_note, { is_collection: false }).serializable_hash
        end

        def create
          chapter_note = ChapterNote.new(chapter_note_params[:attributes].merge(chapter_id: chapter.to_param))

          if chapter_note.save(raise_on_failure: false)
            response.headers['Location'] = api_chapter_chapter_note_url(chapter)
            render json: Api::Admin::Chapters::ChapterNoteSerializer.new(chapter_note, { is_collection: false }).serializable_hash, status: :created
          else
            render json: Api::Admin::ErrorSerializationService.new(chapter_note).call, status: :unprocessable_content
          end
        end

        def update
          chapter_note = chapter.chapter_note
          chapter_note.set(chapter_note_params[:attributes])

          if chapter_note.save(raise_on_failure: false)
            render json: Api::Admin::Chapters::ChapterNoteSerializer.new(chapter_note, { is_collection: false }).serializable_hash, status: :ok
          else
            render json: Api::Admin::ErrorSerializationService.new(chapter_note).call, status: :unprocessable_content
          end
        end

        def destroy
          chapter_note = chapter.chapter_note

          raise Sequel::RecordNotFound if chapter_note.blank?

          chapter_note.destroy

          head :no_content
        end

        private

        def chapter_note_params
          params.require(:data).permit(:type, attributes: [:content])
        end

        def chapter
          @chapter ||= Chapter.by_code(chapter_id).take
        end

        def chapter_id
          params[:chapter_id]
        end
      end
    end
  end
end
