module CustomsTariffImporter
  class Importer
    S3_KEY_PREFIX = 'data/customs_tariff_documents'.freeze

    Result = Data.define(:status, :version, :error) do
      def initialize(status:, version: nil, error: nil)
        super
      end
    end

    def call
      documents = DocumentFetcher.new.call
      raise 'No documents found on GOV.UK publication page' if documents.empty?

      documents.map { |doc| import_document(doc) }
    end

    private

    def import_document(fetched)
      if CustomsTariffUpdate.where(version: fetched.version).any?
        Instrumentation.document_skipped(version: fetched.version, reason: :already_imported)
        return Result.new(status: :skipped, version: fetched.version)
      end

      if CustomsTariffUpdate.where(file_checksum: fetched.checksum).any?
        Instrumentation.document_skipped(version: fetched.version, reason: :duplicate_content)
        return Result.new(status: :duplicate_content, version: fetched.version)
      end

      s3_path = "#{S3_KEY_PREFIX}/UKGT_#{fetched.version}.docx"
      TariffSynchronizer::FileService.write_file(s3_path, fetched.content)

      extracted = NotesExtractor.new(fetched.version, fetched.content).call

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      CustomsTariffUpdate.db.transaction do
        update = CustomsTariffUpdate.create(
          version: fetched.version,
          validity_start_date: fetched.entry_into_force_on || fetched.published_on || Time.zone.today,
          status: CustomsTariffUpdate::PENDING,
          source_url: fetched.url,
          s3_path:,
          file_checksum: fetched.checksum,
          document_created_on: fetched.published_on,
        )

        extracted.chapters.each do |chapter_id, content|
          CustomsTariffChapterNote.create(customs_tariff_update_version: update.version, chapter_id:, content:)
        end

        extracted.sections.each do |section_id, content|
          CustomsTariffSectionNote.create(customs_tariff_update_version: update.version, section_id:, content:)
        end

        extracted.general_rules.each do |rule_label, content|
          CustomsTariffGeneralRule.create(customs_tariff_update_version: update.version, rule_label:, content:)
        end
      end

      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
      Instrumentation.document_imported(version: fetched.version, duration_ms:)

      Result.new(status: :imported, version: fetched.version)
    rescue StandardError => e
      Instrumentation.document_import_failed(
        version: fetched&.version,
        error_class: e.class.name,
        error_message: e.message,
      )
      record_failure(fetched&.version, e.message)
      Result.new(status: :failed, version: fetched&.version, error: e.message)
    end

    def record_failure(version, message)
      return if version.blank?
      return if CustomsTariffUpdate.where(version:).any?

      CustomsTariffUpdate.create(
        version:,
        validity_start_date: Time.zone.today,
        status: CustomsTariffUpdate::FAILED,
        import_error: message,
      )
    rescue StandardError => e
      Rails.logger.error "Failed to record import failure: #{e.message}"
    end
  end
end
