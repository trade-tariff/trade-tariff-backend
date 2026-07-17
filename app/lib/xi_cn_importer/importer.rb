# Importer for the XI Combined Nomenclature (CN) — the EU tariff schedule
# published annually in the Official Journal and served via the EU Cellar CDN.
module XiCnImporter
  class Importer
    S3_KEY_PREFIX = 'data/customs_tariff_documents/xi'.freeze

    Result = Data.define(:status, :celex, :error) do
      def initialize(status:, celex: nil, error: nil)
        super
      end
    end

    def call
      documents = DocumentFetcher.new.call
      documents.map { |doc| import_document(doc) }
    end

  private

    def import_document(fetched)
      s3_path      = "#{S3_KEY_PREFIX}/CN_#{fetched.celex}.pdf"
      html_s3_path = "#{S3_KEY_PREFIX}/CN_#{fetched.celex}.xhtml"
      TariffSynchronizer::FileService.write_file(s3_path, fetched.pdf_content)
      TariffSynchronizer::FileService.write_file(html_s3_path, fetched.html_content)

      extracted = NotesExtractor.new(fetched.celex, fetched.html_content).call

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      persist_document(fetched, extracted, s3_path)

      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
      Instrumentation.document_imported(celex: fetched.celex, duration_ms:)

      Result.new(status: :imported, celex: fetched.celex)
    rescue StandardError => e
      Instrumentation.document_import_failed(
        celex: fetched&.celex,
        error_class: e.class.name,
        error_message: e.message,
      )
      record_failure(fetched&.celex, e.message)
      Result.new(status: :failed, celex: fetched&.celex, error: e.message)
    end

    def persist_document(fetched, extracted, s3_path)
      CustomsTariffUpdate.db.transaction do
        CustomsTariffUpdate.failed.where(version: fetched.celex).delete
        update = create_update(fetched, s3_path)
        persist_sections(update, extracted.sections)
        persist_chapters(update, extracted.chapters)
        persist_general_rules(update, extracted.general_rules)
      end
    end

    def create_update(fetched, s3_path)
      CustomsTariffUpdate.create(
        version: fetched.celex,
        validity_start_date: fetched.force_date,
        source_url: fetched.cellar_url,
        s3_path:,
        file_checksum: fetched.pdf_checksum,
        document_created_on: fetched.publication_date,
      )
    end

    def persist_sections(update, sections)
      sections.each do |section_id, content|
        CustomsTariffSectionNote.create(
          customs_tariff_update_version: update.version,
          section_id:,
          content:,
          validity_start_date: update.validity_start_date,
        )
      end
    end

    def persist_chapters(update, chapters)
      chapters.each do |chapter_id, content|
        CustomsTariffChapterNote.create(
          customs_tariff_update_version: update.version,
          chapter_id:,
          content:,
          validity_start_date: update.validity_start_date,
        )
      end
    end

    def persist_general_rules(update, general_rules)
      general_rules.each do |rule_label, content|
        CustomsTariffGeneralRule.create(
          customs_tariff_update_version: update.version,
          rule_label:,
          content:,
          validity_start_date: update.validity_start_date,
        )
      end
    end

    def record_failure(celex, message)
      return if celex.blank?
      return if CustomsTariffUpdate.imported.where(version: celex).any?

      CustomsTariffUpdate.failed.where(version: celex).delete
      CustomsTariffUpdate.create(
        version: celex,
        validity_start_date: Time.zone.today,
        import_error: message,
      )
    rescue StandardError => e
      Rails.logger.error "Failed to record XI import failure: #{e.message}"
    end
  end
end
