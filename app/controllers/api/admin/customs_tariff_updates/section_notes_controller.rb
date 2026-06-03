module Api
  module Admin
    module CustomsTariffUpdates
      class SectionNotesController < BaseController
        def index
          notes = CustomsTariffSectionNote
            .where(customs_tariff_update_version: customs_tariff_update.version)
            .order(:section_id).all

          baseline_by_section = compare_notes_index

          file_diffs = notes.each_with_object({}) do |note, diffs|
            baseline = baseline_by_section[note.section_id]
            diffs[note.section_id] = if baseline.nil?
                                       nil
                                     else
                                       content_diff(baseline, note)
                                     end
          end

          render json: Api::Admin::CustomsTariffUpdates::SectionNoteSerializer.new(
            notes, is_collection: true, params: { file_diffs: }
          ).serializable_hash
        end

        def show
          note = customs_tariff_section_note

          if params[:compare_version].present?
            compare_note = CustomsTariffSectionNote
              .where(section_id: note.section_id,
                     customs_tariff_update_version: params[:compare_version])
              .first

            file_diff = content_diff(compare_note, note) if compare_note

            render json: Api::Admin::CustomsTariffUpdates::SectionNoteSerializer.new(
              note, is_collection: false, params: { file_diff: }
            ).serializable_hash
          else
            versions = note.versions.order(Sequel.desc(:created_at)).all
            Version.preload_predecessors(versions)

            render json: Api::Admin::CustomsTariffUpdates::SectionNoteSerializer.new(
              note, is_collection: false, params: { versions: }
            ).serializable_hash
          end
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

        def compare_notes_index
          if params[:compare_version].present?
            CustomsTariffSectionNote
              .where(customs_tariff_update_version: params[:compare_version])
              .all.index_by(&:section_id)
          else
            approved_notes_index
          end
        end

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

        def content_diff(from_note, to_note)
          VersionDiffService.new(
            'CustomsTariffSectionNote',
            { 'content' => from_note.content },
            { 'content' => to_note.content },
          ).call || {}
        end

        def section_note_params
          params.require(:data).require(:attributes).permit(:content)
        end
      end
    end
  end
end
