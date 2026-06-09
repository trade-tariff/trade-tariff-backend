module Api
  module Admin
    module CustomsTariffUpdates
      class ChapterNotesController < BaseController
        def index
          notes = CustomsTariffChapterNote
            .where(customs_tariff_update_version: customs_tariff_update.version)
            .then { |ds| filter_by_section(ds) }
            .order(:chapter_id).all

          baseline_by_chapter = compare_notes_index

          file_diffs = notes.each_with_object({}) do |note, diffs|
            baseline = baseline_by_chapter[note.chapter_id]
            diffs[note.chapter_id] = baseline.nil? ? nil : content_diff(baseline, note)
          end

          render json: Api::Admin::CustomsTariffUpdates::ChapterNoteSerializer.new(
            notes, is_collection: true, params: { file_diffs: }
          ).serializable_hash
        end

        def show
          note = customs_tariff_chapter_note

          if params[:compare_version].present?
            compare_note = CustomsTariffChapterNote
              .where(chapter_id: note.chapter_id,
                     customs_tariff_update_version: params[:compare_version])
              .first

            file_diff = content_diff(compare_note, note) if compare_note

            render json: Api::Admin::CustomsTariffUpdates::ChapterNoteSerializer.new(
              note, is_collection: false, params: { file_diff: }
            ).serializable_hash
          else
            versions = note.versions.order(Sequel.desc(:created_at)).all
            Version.preload_predecessors(versions)

            render json: Api::Admin::CustomsTariffUpdates::ChapterNoteSerializer.new(
              note, is_collection: false, params: { versions: }
            ).serializable_hash
          end
        end

        def update
          note = customs_tariff_chapter_note

          if customs_tariff_update.status == CustomsTariffUpdate::REJECTED
            render json: { errors: [{ detail: 'Cannot edit a note on a rejected update' }] },
                   status: :unprocessable_content
            return
          end

          note.set(content: chapter_note_params[:content])

          if note.save(raise_on_failure: false)
            render json: Api::Admin::CustomsTariffUpdates::ChapterNoteSerializer.new(note, is_collection: false).serializable_hash
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

          note = CustomsTariffChapterNote.new(
            customs_tariff_update_version: customs_tariff_update.version,
            chapter_id: create_params[:chapter_id],
            content: create_params[:content],
            validity_start_date: customs_tariff_update.validity_start_date,
            status: CustomsTariffChapterNote::PENDING,
          )

          if note.save(raise_on_failure: false)
            render json: Api::Admin::CustomsTariffUpdates::ChapterNoteSerializer.new(
              note, is_collection: false
            ).serializable_hash, status: :created
          else
            render json: Api::Admin::ErrorSerializationService.new(note).call,
                   status: :unprocessable_content
          end
        rescue Sequel::UniqueConstraintViolation
          render json: { errors: [{ detail: 'A note for this chapter already exists on this update' }] },
                 status: :unprocessable_content
        end

        def destroy
          note = customs_tariff_chapter_note

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

        def filter_by_section(dataset)
          return dataset if params[:section_id].blank?

          ids = chapter_ids_for_section(params[:section_id].to_i)
          ids.any? ? dataset.where(chapter_id: ids) : dataset.where(Sequel.lit('false'))
        end

        def chapter_ids_for_section(section_id)
          Sequel::Model.db.fetch(<<~SQL, section_id:).map { |r| r[:chapter_code] }
            SELECT LEFT(gn.goods_nomenclature_item_id, 2) AS chapter_code
            FROM   chapters_sections cs
            JOIN   goods_nomenclatures gn
                     ON gn.goods_nomenclature_sid = cs.goods_nomenclature_sid
            WHERE  gn.goods_nomenclature_item_id LIKE '__00000000'
              AND  cs.section_id = :section_id
          SQL
        end

        def compare_notes_index
          if params[:compare_version].present?
            CustomsTariffChapterNote
              .where(customs_tariff_update_version: params[:compare_version])
              .all.index_by(&:chapter_id)
          else
            previous_notes_index
          end
        end

        def customs_tariff_chapter_note
          @customs_tariff_chapter_note ||= CustomsTariffChapterNote
            .where(id: params[:id], customs_tariff_update_version: customs_tariff_update.version)
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

          CustomsTariffChapterNote
            .where(customs_tariff_update_version: prev.version)
            .all.index_by(&:chapter_id)
        end

        def content_diff(from_note, to_note)
          VersionDiffService.new(
            'CustomsTariffChapterNote',
            { 'content' => from_note.content },
            { 'content' => to_note.content },
          ).call || {}
        end

        def chapter_note_params
          params.require(:data).require(:attributes).permit(:content)
        end

        def create_params
          params.require(:data).require(:attributes).permit(:chapter_id, :content)
        end
      end
    end
  end
end
