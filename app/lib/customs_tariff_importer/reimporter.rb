module CustomsTariffImporter
  # this class is responsible for re-importing customs tariff notes from stored S3 documents into the database as part of rake task "importer:customs_tariff:reimport"
  class Reimporter
    def call(version: nil)
      if version
        update = CustomsTariffUpdate.first(version:)
        reimport(update) if update # no-op if the version does not exist
      else
        CustomsTariffUpdate.exclude(status: CustomsTariffUpdate::FAILED).each do |update|
          reimport(update)
        end
      end
    end

    private

    def reimport(update)
      content = TariffSynchronizer::FileService.get(update.s3_path).read
      extracted = NotesExtractor.new(update.version, content).call

      CustomsTariffUpdate.db.transaction do
        CustomsTariffSectionNote.where(customs_tariff_update_version: update.version).delete
        CustomsTariffChapterNote.where(customs_tariff_update_version: update.version).delete
        CustomsTariffGeneralRule.where(customs_tariff_update_version: update.version).delete

        extracted.sections.each do |section_id, note_content|
          CustomsTariffSectionNote.create(
            customs_tariff_update_version: update.version,
            section_id:,
            content: note_content,
            validity_start_date: update.validity_start_date,
            status: CustomsTariffSectionNote::PENDING,
          )
        end

        extracted.chapters.each do |chapter_id, note_content|
          CustomsTariffChapterNote.create(
            customs_tariff_update_version: update.version,
            chapter_id:,
            content: note_content,
            validity_start_date: update.validity_start_date,
            status: CustomsTariffChapterNote::PENDING,
          )
        end

        extracted.general_rules.each do |rule_label, note_content|
          CustomsTariffGeneralRule.create(
            customs_tariff_update_version: update.version,
            rule_label:,
            content: note_content,
            validity_start_date: update.validity_start_date,
            status: CustomsTariffGeneralRule::PENDING,
          )
        end
      end
    end
  end
end
