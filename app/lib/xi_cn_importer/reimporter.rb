require 'net/http'

module XiCnImporter
  class Reimporter
    MAX_REDIRECTS = 5
    OPEN_TIMEOUT  = 10
    READ_TIMEOUT  = 30
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
      html_content = fetch_html(update.source_url)
      extracted    = NotesExtractor.new(update.version, html_content).call

      if extracted.chapters.empty? && extracted.sections.empty? && extracted.general_rules.empty?
        raise "Empty extract for #{update.version} — refusing to wipe notes"
      end

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

    def fetch_html(url, redirect_count: 0)
      raise 'Too many redirects' if redirect_count > MAX_REDIRECTS

      uri      = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.get(uri.request_uri, 'Accept' => 'application/xhtml+xml')
      end

      case response
      when Net::HTTPSuccess then response.body
      when Net::HTTPRedirection
        location = response['location']
        fetch_html(URI.join(url, location).to_s, redirect_count: redirect_count + 1)
      else raise "Failed to fetch #{url}: HTTP #{response.code}"
      end
    end
  end
end
