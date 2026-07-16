module XiCnImporter
  class Reimporter
    S3_KEY_PREFIX = 'data/customs_tariff_documents/xi'.freeze

    def call(version: nil)
      if version
        update = CustomsTariffUpdate.first(version:)
        reimport(update) if update && update.s3_path&.start_with?("#{S3_KEY_PREFIX}/")
      else
        CustomsTariffUpdate.exclude(status: CustomsTariffUpdate::FAILED).each do |update|
          next unless update.s3_path&.start_with?("#{S3_KEY_PREFIX}/")

          reimport(update)
        rescue StandardError => e
          XiCnImporter::Instrumentation.reimport_failed(
            version: update.version,
            error_class: e.class.name,
            error_message: e.message,
          )
        end
      end
    end

  private

    def reimport(update)
      html_s3_path = "#{S3_KEY_PREFIX}/CN_#{update.version}.xhtml"
      html_content = TariffSynchronizer::FileService.get(html_s3_path).read
      extracted    = NotesExtractor.new(update.version, html_content).call

      if extracted.chapters.empty? && extracted.sections.empty? && extracted.general_rules.empty?
        raise "Empty extract for #{update.version} — refusing to wipe notes"
      end

      CustomsTariffUpdate.db.transaction do
        CustomsTariffSectionNote.where(customs_tariff_update_version: update.version).delete
        CustomsTariffChapterNote.where(customs_tariff_update_version: update.version).delete
        CustomsTariffGeneralRule.where(customs_tariff_update_version: update.version).delete

        create_section_notes(update, extracted.sections)

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

    def create_section_notes(update, sections)
      sections.each do |section_id, note_content|
        CustomsTariffSectionNote.create(
          customs_tariff_update_version: update.version,
          section_id:,
          content: note_content,
          validity_start_date: update.validity_start_date,
          status: CustomsTariffSectionNote::PENDING,
        )
      end
    end
  end
end
