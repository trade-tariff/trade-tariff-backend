require 'date'
require 'net/http'
require 'nokogiri'
require 'uri'

module TariffKnowledge
  class PublicAtarRulingSource
    class ExtractionError < StandardError; end

    Ruling = Data.define(
      :ref,
      :commodity_code,
      :goods_nomenclature_item_id,
      :description,
      :keywords,
      :justification,
      :validity_start_date,
      :validity_end_date,
      :source_url,
      :raw_fields,
    )

    BASE_URL = 'https://www.tax.service.gov.uk/search-for-advance-tariff-rulings'.freeze
    USER_AGENT = 'trade-tariff-backend-atar-import/1.0'.freeze
    DEFAULT_REQUEST_DELAY = 0.25
    DEFAULT_MAX_RETRIES = 3
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 30
    TRANSIENT_RESPONSE_CODES = %w[408 429 500 502 503 504].freeze

    def self.call(...) = new(...).call

    def initialize(limit: nil, max_pages: 50, request_delay: DEFAULT_REQUEST_DELAY, max_retries: DEFAULT_MAX_RETRIES)
      @limit = limit
      @max_pages = max_pages
      @request_delay = request_delay.to_f
      @max_retries = max_retries.to_i
    end

    def call
      refs.map { |ref| ruling_for_ref(ref) }
    end

    def refs
      listing_refs
    end

    def refs_for_page(page)
      refs_from_listing_page(page)
    end

    def ruling_for_ref(ref)
      ruling(ref)
    end

  private

    attr_reader :limit, :max_pages, :request_delay, :max_retries

    def listing_refs
      refs = []
      page = 1

      while page <= max_pages && (limit.nil? || refs.size < limit)
        page_refs = refs_from_listing_page(page)
        break if page_refs.empty?

        refs.concat(page_refs)
        page += 1
      end

      refs.uniq.first(limit || refs.size)
    end

    def refs_from_listing_page(page)
      document = Nokogiri::HTML(fetch_html("/search?page=#{page}"))
      document.css('a').filter_map do |link|
        next unless link.text.include?('View ruling')

        href = link['href'].to_s
        href.split('/').last if href.match?(%r{/ruling/\d+\z})
      end
    end

    def ruling(ref)
      document = Nokogiri::HTML(fetch_html("/ruling/#{ref}"))
      raw_fields = ruling_fields(document)
      keywords = Array(raw_fields['Keywords'])
      commodity_code = extract_commodity_code(raw_fields, ref)

      Ruling.new(
        ref:,
        commodity_code:,
        goods_nomenclature_item_id: normalized_goods_nomenclature_item_id(commodity_code),
        description: raw_fields.fetch('Description', ''),
        keywords:,
        justification: raw_fields.fetch('Justification', ''),
        validity_start_date: parse_required_date(raw_fields, 'Start date', ref),
        validity_end_date: parse_required_date(raw_fields, 'Expiry date', ref),
        source_url: "#{BASE_URL}/ruling/#{ref}",
        raw_fields:,
      )
    end

    def ruling_fields(document)
      fields = {}
      document.css('dl#ruling-details .govuk-summary-list__row, dl.govuk-summary-list .govuk-summary-list__row').each do |row|
        key = row.at_css('.govuk-summary-list__key')&.text&.squish
        next if key.blank?

        value_node = row.at_css('.govuk-summary-list__value')
        fields[key] = key == 'Keywords' ? keywords(value_node) : value_node&.text&.squish
      end
      fields.compact
    end

    def keywords(value_node)
      value_node
        &.css('.govuk-tag-atar, #keyword-list li, .govuk-tag')
        &.filter_map { |node| node.text.squish.presence }
        &.uniq || []
    end

    def extract_commodity_code(raw_fields, ref)
      commodity_code = raw_fields.fetch('Commodity code', '').to_s
                             .scan(/\d{6,10}/)
                             .find { |code| valid_commodity_code?(code) }
      return commodity_code if commodity_code.present?

      raise ExtractionError, "Missing valid Commodity code for public ATAR #{ref}"
    end

    def valid_commodity_code?(code)
      code.match?(/\A\d{6}(?:\d{2}){0,2}\z/)
    end

    def parse_required_date(raw_fields, key, ref)
      value = raw_fields[key]
      raise ExtractionError, "Missing #{key} for public ATAR #{ref}" if value.blank?

      Date.parse(value)
    rescue Date::Error
      raise ExtractionError, "Invalid #{key} for public ATAR #{ref}: #{value.inspect}"
    end

    def normalized_goods_nomenclature_item_id(commodity_code)
      commodity_code.ljust(10, '0')
    end

    def fetch_html(path)
      uri = URI("#{BASE_URL}#{path}")
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = USER_AGENT

      response = with_retries(uri) do
        sleep request_delay if request_delay.positive?

        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
          http.request(request)
        end
      end
      raise "GET #{uri} failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    end

    def with_retries(uri)
      attempts = 0

      loop do
        response = yield
        return response unless retryable_response?(response) && attempts < max_retries

        attempts += 1
        Rails.logger.warn("Retrying ATAR fetch #{uri} after HTTP #{response.code}")
        sleep retry_after(response)
      end
    rescue EOFError, Net::ReadTimeout, Net::OpenTimeout, Errno::ECONNRESET => e
      raise e if attempts >= max_retries

      attempts += 1
      Rails.logger.warn("Retrying ATAR fetch #{uri} after #{e.class}: #{e.message}")
      sleep request_delay
      retry
    end

    def retryable_response?(response)
      TRANSIENT_RESPONSE_CODES.include?(response.code)
    end

    def retry_after(response)
      value = response['Retry-After'].to_s
      return request_delay if value.blank?

      Float(value)
    rescue ArgumentError
      request_delay
    end
  end
end
