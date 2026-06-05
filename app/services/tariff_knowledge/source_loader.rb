module TariffKnowledge
  class SourceLoader
    def self.call
      new.call
    end

    def call
      customs_chapter_notes + customs_section_notes
    end

  private

    def customs_chapter_notes
      CustomsTariffChapterNote
        .approved
        .where(customs_tariff_update_version: CustomsTariffUpdate.actual.select(:version))
        .order(:chapter_id)
        .all
        .map do |note|
        chapter_id = note.chapter_id.to_s.rjust(2, '0')

        RuleSource.new(
          key: "customs_tariff_chapter_note:#{note.customs_tariff_update_version}:#{chapter_id}",
          source_type: 'CustomsTariffChapterNote',
          source_id: chapter_id,
          source_version: note.customs_tariff_update_version,
          title: "Chapter #{chapter_id} note",
          content: note.content,
          scope_type: 'chapter',
          scope_id: chapter_id,
          validity_start_date: note.validity_start_date,
          validity_end_date: note.validity_end_date,
        )
      end
    end

    def customs_section_notes
      CustomsTariffSectionNote
        .approved
        .where(customs_tariff_update_version: CustomsTariffUpdate.actual.select(:version))
        .order(:section_id)
        .all
        .map do |note|
        RuleSource.new(
          key: "customs_tariff_section_note:#{note.customs_tariff_update_version}:#{note.section_id}",
          source_type: 'CustomsTariffSectionNote',
          source_id: note.section_id.to_s,
          source_version: note.customs_tariff_update_version,
          title: "Section #{note.section_id} note",
          content: note.content,
          scope_type: 'section',
          scope_id: note.section_id,
          validity_start_date: note.validity_start_date,
          validity_end_date: note.validity_end_date,
        )
      end
    end
  end
end
