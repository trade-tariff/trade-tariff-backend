class ImportCustomsTariffDocumentService
  S3_KEY_PREFIX = 'data/customs_tariff_documents'.freeze

  Result = Struct.new(:status, :version, :error, keyword_init: true)

  # Returns an array of Result objects, one per document found on GOV.UK.
  def call
    documents = GovUkTariffDocumentFetcher.new.call
    raise 'No documents found on GOV.UK publication page' if documents.empty?

    documents.map { |doc| import_document(doc) }
  rescue StandardError => e
    Rails.logger.error "ImportCustomsTariffDocumentService failed: #{e.class}: #{e.message}"
    [Result.new(status: :failed, error: e.message)]
  end

  private

  def import_document(fetched)
    if CustomsTariffUpdate.where(version: fetched.version).any?
      Rails.logger.info "CustomsTariffUpdate #{fetched.version} already imported — skipping"
      return Result.new(status: :skipped, version: fetched.version)
    end

    if CustomsTariffUpdate.where(file_checksum: fetched.checksum).any?
      Rails.logger.info "CustomsTariffUpdate with checksum #{fetched.checksum} already exists — skipping duplicate content"
      return Result.new(status: :duplicate_content, version: fetched.version)
    end

    s3_path = "#{S3_KEY_PREFIX}/UKGT_#{fetched.version}.docx"
    TariffSynchronizer::FileService.write_file(s3_path, fetched.content)

    extracted = TariffNotesExtractor.new(fetched.content).call

    CustomsTariffUpdate.db.transaction do
      update = CustomsTariffUpdate.create(
        version: fetched.version,
        validity_start_date: fetched.entry_into_force_on || fetched.published_on || Time.zone.today,
        status: CustomsTariffUpdate::AWAITING_APPROVAL,
        source_url: fetched.url,
        s3_path:,
        file_checksum: fetched.checksum,
        document_created_on: fetched.published_on,
      )

      extracted.chapters.each do |chapter_id, content|
        CustomsTariffChapterNote.create(
          customs_tariff_update_version: update.version,
          chapter_id:,
          content:,
        )
      end

      extracted.sections.each do |section_id, content|
        CustomsTariffSectionNote.create(
          customs_tariff_update_version: update.version,
          section_id:,
          content:,
        )
      end

      extracted.general_rules.each do |rule_label, content|
        CustomsTariffGeneralRule.create(
          customs_tariff_update_version: update.version,
          rule_label:,
          content:,
        )
      end
    end

    Rails.logger.info "Imported CustomsTariffUpdate #{fetched.version}"
    Result.new(status: :imported, version: fetched.version)
  rescue StandardError => e
    Rails.logger.error "ImportCustomsTariffDocumentService failed for version #{fetched&.version}: #{e.class}: #{e.message}"
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
