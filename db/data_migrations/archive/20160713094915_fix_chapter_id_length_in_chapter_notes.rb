TradeTariffBackend::DataMigrator.migration do
  name "Fix chapter_id attribute at least 2 chars in the ChapterNote model"

  up do
    applicable {
      ChapterNote.where("char_length(chapter_id) < 2").any?
      false
    }
    apply {
      ChapterNote.all do |chapter_note|
        chapter_note.update(chapter_id: sprintf("%02d", chapter_note.chapter_id.to_i))
      end
    }
  end

  down do
    applicable { false }
    apply { } # noop
  end
end
