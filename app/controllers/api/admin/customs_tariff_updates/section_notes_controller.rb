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

          note.set(content: update_params[:content])

          if note.save(raise_on_failure: false)
            CustomsTariffImporter::Instrumentation.section_note_updated(
              version: customs_tariff_update.version,
              section_id: note.section_id,
              note_id: note.id,
              whodunnit: TradeTariffRequest.whodunnit,
            )

            render json: Api::Admin::CustomsTariffUpdates::SectionNoteSerializer.new(note, is_collection: false).serializable_hash
          else
            render json: Api::Admin::ErrorSerializationService.new(note).call, status: :unprocessable_content
          end
        end

        def create
          if customs_tariff_update.status == CustomsTariffUpdate::REJECTED
            render json: { errors: [{ detail: 'Cannot add a note to a rejected update' }] },
                   status: :unprocessable_content
            return
          end

          note = CustomsTariffSectionNote.new(
            customs_tariff_update_version: customs_tariff_update.version,
            section_id: create_params[:section_id].to_i,
            content: create_params[:content],
            validity_start_date: customs_tariff_update.validity_start_date,
            status: CustomsTariffSectionNote::PENDING,
          )

          if note.save(raise_on_failure: false)
            render json: Api::Admin::CustomsTariffUpdates::SectionNoteSerializer.new(
              note, is_collection: false
            ).serializable_hash, status: :created
          else
            render json: Api::Admin::ErrorSerializationService.new(note).call,
                   status: :unprocessable_content
          end
        end

        def destroy
          note = customs_tariff_section_note

          if customs_tariff_update.status == CustomsTariffUpdate::REJECTED
            render json: { errors: [{ detail: 'Cannot remove a note from a rejected update' }] },
                   status: :unprocessable_content
            return
          end

          note.destroy
          head :no_content
        rescue Sequel::HookFailed
          render json: { errors: [{ detail: 'Could not remove the note' }] },
                 status: :unprocessable_content
        end

        private

        def compare_notes_index
          if params[:compare_version].present?
            CustomsTariffSectionNote
              .where(customs_tariff_update_version: params[:compare_version])
              .all.index_by(&:section_id)
          else
            previous_notes_index
          end
        end

        def customs_tariff_section_note
          @customs_tariff_section_note ||= CustomsTariffSectionNote
            .where(section_id: params[:id], customs_tariff_update_version: customs_tariff_update.version)
            .first.tap { |n| raise Sequel::RecordNotFound unless n }
        end

        def previous_notes_index
          current_date = customs_tariff_update.validity_start_date
          prev = CustomsTariffUpdate
            .exclude(status: CustomsTariffUpdate::FAILED)
            .where { validity_start_date < current_date }
            .order(Sequel.desc(:validity_start_date))
            .first
          return {} unless prev

          CustomsTariffSectionNote
            .where(customs_tariff_update_version: prev.version)
            .all.index_by(&:section_id)
        end

        def content_diff(from_note, to_note)
          VersionDiffService.new(
            'CustomsTariffSectionNote',
            { 'content' => from_note.content },
            { 'content' => to_note.content },
          ).call || {}
        end

        def update_params
          params.require(:data).require(:attributes).permit(:content)
        end

        def create_params
          params.require(:data).require(:attributes).permit(:content, :section_id)
        end
      end
    end
  end
end
