module Api
  module Admin
    module CustomsTariffUpdates
      class SectionNotesController < BaseController
        def index
          notes = CustomsTariffSectionNote
            .where(customs_tariff_update_version: customs_tariff_update.version)
            .order(:section_id).all

          approved_by_section = approved_notes_index

          file_diffs = notes.each_with_object({}) do |note, diffs|
            approved = approved_by_section[note.section_id]
            diffs[note.section_id] = if approved.nil?
                                       nil
                                     else
                                       VersionDiffService.new(
                                         'CustomsTariffSectionNote',
                                         approved.values.transform_keys(&:to_s),
                                         note.values.transform_keys(&:to_s),
                                       ).call || {}
                                     end
          end

          render json: Api::Admin::CustomsTariffUpdates::SectionNoteSerializer.new(
            notes, is_collection: true, params: { file_diffs: }
          ).serializable_hash
        end

        def show
          note = customs_tariff_section_note
          versions = note.versions.order(Sequel.desc(:created_at)).all
          Version.preload_predecessors(versions)

          render json: Api::Admin::CustomsTariffUpdates::SectionNoteSerializer.new(
            note, is_collection: false, params: { versions: }
          ).serializable_hash
        end

        def update
          note = customs_tariff_section_note

          if customs_tariff_update.status == CustomsTariffUpdate::REJECTED
            render json: { errors: [{ detail: 'Cannot edit a note on a rejected update' }] },
                   status: :unprocessable_content
            return
          end

          note.set(content: section_note_params[:content])

          if note.save(raise_on_failure: false)
            render json: Api::Admin::CustomsTariffUpdates::SectionNoteSerializer.new(note, is_collection: false).serializable_hash
          else
            render json: Api::Admin::ErrorSerializationService.new(note).call, status: :unprocessable_content
          end
        end

        private

        def customs_tariff_section_note
          @customs_tariff_section_note ||= CustomsTariffSectionNote
            .where(id: params[:id], customs_tariff_update_version: customs_tariff_update.version)
            .first.tap { |n| raise Sequel::RecordNotFound unless n }
        end

        def approved_notes_index
          latest_approved = CustomsTariffUpdate.approved.order(Sequel.desc(:validity_start_date)).first
          return {} unless latest_approved

          CustomsTariffSectionNote
            .where(customs_tariff_update_version: latest_approved.version)
            .all.index_by(&:section_id)
        end

        def section_note_params
          params.require(:data).require(:attributes).permit(:content)
        end
      end
    end
  end
end
