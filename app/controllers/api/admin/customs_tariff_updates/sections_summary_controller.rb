module Api
  module Admin
    module CustomsTariffUpdates
      class SectionsSummaryController < BaseController
        def index
          sections          = Section.order(:position).all
          notes_for_update  = notes_index_for(customs_tariff_update.version)
          baseline_notes    = baseline_section_notes
          chapter_notes     = CustomsTariffChapterNote
                                .where(customs_tariff_update_version: customs_tariff_update.version)
                                .all
          baseline_chapters = baseline_chapter_notes
          chapter_section   = chapter_to_section_map
          chapter_counts    = chapter_counts_by_section(chapter_notes, baseline_chapters, chapter_section)

          summaries = sections.map do |section|
            note   = notes_for_update[section.id]
            diff   = note ? section_note_diff(baseline_notes[section.id], note) : nil
            status = section_note_status(note, diff)
            counts = chapter_counts[section.id] || { total: 0, changed: 0 }

            SectionSummary.new(
              section_id: section.id,
              section_title: section.title,
              position: section.position,
              section_note_id: note&.id,
              section_note_status: status,
              chapter_notes_total: counts[:total],
              chapter_notes_changed: counts[:changed],
            )
          end

          render json: Api::Admin::CustomsTariffUpdates::SectionSummarySerializer.new(
            summaries, is_collection: true
          ).serializable_hash
        end

      private

        def notes_index_for(version)
          CustomsTariffSectionNote
            .where(customs_tariff_update_version: version)
            .all.index_by(&:section_id)
        end

        def baseline_section_notes
          if params[:compare_version].present?
            notes_index_for(params[:compare_version])
          else
            prev = previous_update
            prev ? notes_index_for(prev.version) : {}
          end
        end

        def baseline_chapter_notes
          if params[:compare_version].present?
            CustomsTariffChapterNote
              .where(customs_tariff_update_version: params[:compare_version])
              .all.index_by(&:chapter_id)
          else
            prev = previous_update
            return {} unless prev

            CustomsTariffChapterNote
              .where(customs_tariff_update_version: prev.version)
              .all.index_by(&:chapter_id)
          end
        end

        def chapter_to_section_map
          Sequel::Model.db.fetch(<<~SQL).map { |r| [r[:chapter_code], r[:section_id]] }.to_h
            SELECT LEFT(gn.goods_nomenclature_item_id, 2) AS chapter_code,
                   cs.section_id
            FROM   chapters_sections cs
            JOIN   goods_nomenclatures gn
                     ON gn.goods_nomenclature_sid = cs.goods_nomenclature_sid
            WHERE  gn.goods_nomenclature_item_id LIKE '__00000000'
          SQL
        end

        def chapter_counts_by_section(chapter_notes, baseline, chapter_section_map)
          chapter_notes.each_with_object(Hash.new { |h, k| h[k] = { total: 0, changed: 0 } }) do |note, counts|
            section_id = chapter_section_map[note.chapter_id]
            next unless section_id

            counts[section_id][:total] += 1
            baseline_note = baseline[note.chapter_id]
            counts[section_id][:changed] += 1 if baseline_note.nil? || note.content != baseline_note.content
          end
        end

        def section_note_diff(baseline_note, note)
          return nil unless baseline_note

          VersionDiffService.new(
            'CustomsTariffSectionNote',
            { 'content' => baseline_note.content },
            { 'content' => note.content },
          ).call || {}
        end

        def section_note_status(note, diff)
          return :absent    if note.nil?
          return :new       if diff.nil?
          return :unchanged if diff.empty?

          :changed
        end

        def previous_update
          @previous_update ||= begin
            current_date = customs_tariff_update.validity_start_date
            CustomsTariffUpdate
              .exclude(status: CustomsTariffUpdate::FAILED)
              .where { validity_start_date < current_date }
              .order(Sequel.desc(:validity_start_date))
              .first
          end
        end
      end
    end
  end
end
