require 'digest'
require 'net/http'

class GovUkTariffDocumentFetcher
  PUBLICATION_URL = 'https://www.gov.uk/government/publications/reference-document-for-the-customs-tariff-establishment-eu-exit-regulations-2020'.freeze
  MAX_REDIRECTS = 5

  VERSION_PATTERN = /UKGT_(\d+\.\d+)\.docx/i

  Result = Struct.new(:content, :url, :version, :checksum, :published_on, :entry_into_force_on, keyword_init: true)

  # Returns all UKGT .docx documents found on the publication page,
  # sorted by version ascending (oldest first).
  def call
    page_html = fetch_url(PUBLICATION_URL)
    links = all_docx_links(page_html)
    raise "Could not find any .docx attachments on #{PUBLICATION_URL}" if links.empty?

    links.map { |link|
      url  = link[:url]
      text = link[:text]
      Rails.logger.info "Downloading tariff reference document from #{url}"
      content = fetch_url(url)

      Result.new(
        content:,
        url:,
        version: extract_version(url),
        checksum: Digest::SHA256.hexdigest(content),
        published_on: parse_dated_date(text),
        entry_into_force_on: parse_entry_into_force_date(text),
      )
    }.sort_by { |r| Gem::Version.new(r.version) }
  end

  private

  # Returns all .docx attachment links from the GOV.UK publication page,
  # each as { url:, text: } where text is the full link text containing
  # the "dated" and "entry into force" dates.
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

  # Parses the "entry into force" date from attachment link text.
  # Example input: "The Tariff of the United Kingdom, version 1.30, dated 14 January 2026 (entry into force 22 January 2026)"
  def parse_entry_into_force_date(text)
    m = text.match(/entry into force\s+(\d+\s+\w+\s+\d{4})/i)
    Date.parse(m[1]) if m
  rescue ArgumentError
    nil
  end

  # Parses the "dated" publication date from attachment link text.
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
