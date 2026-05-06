require 'digest'
require 'net/http'

module CustomsTariffImporter
  class DocumentFetcher
    PUBLICATION_URL = 'https://www.gov.uk/government/publications/reference-document-for-the-customs-tariff-establishment-eu-exit-regulations-2020'.freeze
    MAX_REDIRECTS = 5
    VERSION_PATTERN = /UKGT_(\d+\.\d+)\.docx/i

    Result = Data.define(:content, :url, :version, :checksum, :published_on, :entry_into_force_on)

    def call
      Instrumentation.fetch_started(url: PUBLICATION_URL)

      page_html = fetch_url(PUBLICATION_URL)
      links = all_docx_links(page_html)
      raise "Could not find any .docx attachments on #{PUBLICATION_URL}" if links.empty?

      links.map { |link|
        url  = link[:url]
        text = link[:text]
        version = extract_version(url)

        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        content = fetch_url(url)
        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)

        Instrumentation.document_fetched(version:, duration_ms:)

        Result.new(
          content:,
          url:,
          version:,
          checksum: Digest::SHA256.hexdigest(content),
          published_on: parse_dated_date(text),
          entry_into_force_on: parse_entry_into_force_date(text),
        )
      }.sort_by { |r| Gem::Version.new(r.version) }
    rescue StandardError => e
      Instrumentation.fetch_failed(url: PUBLICATION_URL, error_class: e.class.name, error_message: e.message)
      raise
    end

    private

    def all_docx_links(html)
      doc = Nokogiri::HTML(html)
      doc.css('h3.gem-c-attachment__title a[href]').filter_map do |a|
        next unless a['href'].match?(/assets\.publishing\.service\.gov\.uk\/.+\.docx(\?|$)/i)

        { url: a['href'], text: a.text.strip }
      end
    end

    def extract_version(url)
      url.match(VERSION_PATTERN)&.captures&.first
    end

    def parse_entry_into_force_date(text)
      m = text.match(/entry into force\s+(\d+\s+\w+\s+\d{4})/i)
      Date.parse(m[1]) if m
    rescue ArgumentError
      nil
    end

    def parse_dated_date(text)
      m = text.match(/dated\s+(\d+\s+\w+\s+\d{4})/i)
      Date.parse(m[1]) if m
    rescue ArgumentError
      nil
    end

    def fetch_url(url, redirect_count: 0)
      raise "Too many redirects fetching #{url}" if redirect_count > MAX_REDIRECTS

      uri = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.get(uri.request_uri)
      end

      case response
      when Net::HTTPSuccess
        response.body
      when Net::HTTPRedirection
        fetch_url(response['location'], redirect_count: redirect_count + 1)
      else
        raise "Failed to fetch #{url}: HTTP #{response.code}"
      end
    end
  end
end
