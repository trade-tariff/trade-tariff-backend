require 'digest'
require 'json'
require 'net/http'

module XiCnImporter
  class DocumentFetcher
    include RetrySupport::WithRetry

    SPARQL_ENDPOINT      = 'https://publications.europa.eu/webapi/rdf/sparql'.freeze
    CELLAR_HTML_TEMPLATE = 'https://publications.europa.eu/resource/cellar/%s.0006.03/DOC_1'.freeze
    CELLAR_PDF_TEMPLATE  = 'https://publications.europa.eu/resource/cellar/%s.0006.01/DOC_1'.freeze
    MAX_REDIRECTS = 5
    OPEN_TIMEOUT  = 10
    READ_TIMEOUT  = 30

    SPARQL_QUERY = <<~SPARQL.freeze
      PREFIX cdm: <http://publications.europa.eu/ontology/cdm#>
      PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>

      SELECT DISTINCT ?work ?celex ?force_date ?pub_date
      WHERE {
        ?work cdm:resource_legal_amends_resource_legal
              <http://publications.europa.eu/resource/cellar/c5a368fa-fd18-4efb-ae18-e4ac4e83055c> .
        ?work cdm:resource_legal_id_celex ?celex .
        ?work cdm:resource_legal_date_entry-into-force ?force_date .
        OPTIONAL { ?work cdm:resource_legal_date_document ?pub_date . }
        FILTER(MONTH(?force_date) = 1 && DAY(?force_date) = 1)
        FILTER(?force_date >= "2024-01-01"^^xsd:date)
      }
      ORDER BY DESC(?force_date)
    SPARQL

    BASE_DELAY = 2 # seconds
    private_constant :BASE_DELAY

    MAX_RETRIES = 3
    private_constant :MAX_RETRIES

    JITTER_RANGE = (0.0..1.0)
    private_constant :JITTER_RANGE

    TRANSIENT_ERRORS = [
      Net::OpenTimeout,
      Net::ReadTimeout,
      Timeout::Error,
      Errno::ECONNRESET,
      Errno::ECONNREFUSED,
      Errno::ETIMEDOUT,
      EOFError,
      SocketError,
    ].freeze
    private_constant :TRANSIENT_ERRORS

    class RetryableHTTPError < StandardError
      attr_reader :http_code

      def initialize(http_code)
        @http_code = http_code.to_i
        super("HTTP #{@http_code}")
      end
    end

    Result = Data.define(
      :celex,
      :force_date,
      :publication_date,
      :cellar_url,
      :html_content,
      :pdf_content,
      :pdf_checksum,
    )

    def call
      bindings = sparql_results

      bindings.filter_map do |binding|
        celex      = binding.dig('celex', 'value')
        work_uri   = binding.dig('work', 'value')
        force_date = Date.parse(binding.dig('force_date', 'value'))
        pub_date   = binding.dig('pub_date', 'value')&.then { |d| Date.parse(d) }

        next if CustomsTariffUpdate
                  .imported
                  .where(version: celex)
                  .any?

        guid        = work_uri.split('/').last
        cellar_url  = sprintf(CELLAR_HTML_TEMPLATE, guid)
        pdf_url     = sprintf(CELLAR_PDF_TEMPLATE, guid)

        start_time   = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        html_content = fetch_html(cellar_url)
        pdf_content  = fetch_binary(pdf_url)
        duration_ms  = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)

        Instrumentation.document_fetched(celex:, duration_ms:)

        Result.new(
          celex:,
          force_date:,
          publication_date: pub_date,
          cellar_url:,
          html_content:,
          pdf_content:,
          pdf_checksum: Digest::SHA256.hexdigest(pdf_content),
        )
      end
    rescue StandardError => e
      Instrumentation.fetch_failed(
        url: SPARQL_ENDPOINT,
        error_class: e.class.name,
        error_message: e.message,
      )
      raise
    end

    def sparql_results
      uri = URI(SPARQL_ENDPOINT)

      response = with_retry(
        max_attempts: MAX_RETRIES + 1,
        retryable_errors: TRANSIENT_ERRORS + [RetryableHTTPError],
        delay_calculator: method(:retry_delay),
        on_retry: lambda { |attempt:, max_attempts:, delay:, error:, **|
          Instrumentation.fetch_retry(
            url: SPARQL_ENDPOINT,
            attempt:,
            max_attempts:,
            error_class: error.class.name,
            error_message: error.message,
            error_code: error_code_for(error),
            backoff_seconds: delay.round(3),
          )
          Instrumentation.sparql_retry_attempt(
            attempt:,
            max_attempts:,
            error_class: error.class.name,
            error_message: error.message,
            error_code: error_code_for(error),
          )
        },
        on_success: lambda { |attempt:, **|
          retry_attempts = attempt - 1
          Instrumentation.sparql_success_after_retry(retry_attempts:) if retry_attempts.positive?
        },
      ) do
        Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == 'https',
          open_timeout: OPEN_TIMEOUT,
          read_timeout: READ_TIMEOUT,
        ) do |http|
          request = Net::HTTP::Post.new(uri.request_uri)
          request.set_form_data(
            'query' => SPARQL_QUERY,
            'format' => 'application/sparql-results+json',
          )

          response = http.request(request)

          if retryable_response?(response)
            raise RetryableHTTPError, response.code

          end

          response
        end
      end

      raise "SPARQL request failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).dig('results', 'bindings') || []
    end

    def retryable_response?(response)
      response.code.to_i.between?(500, 599)
    end

    def retry_defaults
      {
        max_attempts: MAX_RETRIES + 1,
        retryable_errors: TRANSIENT_ERRORS + [RetryableHTTPError],
        delay_calculator: method(:retry_delay),
      }
    end

    def retry_delay(attempt, _error)
      (BASE_DELAY * (2**(attempt - 1))) + rand(JITTER_RANGE)
    end

    def error_code_for(error)
      return error.http_code if error.respond_to?(:http_code)

      nil
    end

    def fetch_html(url, redirect_count: 0)
      raise "Too many redirects fetching #{url}" if redirect_count > MAX_REDIRECTS

      uri      = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.get(uri.request_uri, 'Accept' => 'application/xhtml+xml')
      end

      case response
      when Net::HTTPSuccess
        response.body
      when Net::HTTPRedirection
        location = response['location']
        fetch_html(URI.join(url, location).to_s, redirect_count: redirect_count + 1)
      else
        raise "Failed to fetch #{url}: HTTP #{response.code}"
      end
    end

    def fetch_binary(url, redirect_count: 0)
      raise "Too many redirects fetching #{url}" if redirect_count > MAX_REDIRECTS

      uri      = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.get(uri.request_uri)
      end

      case response
      when Net::HTTPSuccess
        response.body
      when Net::HTTPRedirection
        location = response['location']
        fetch_binary(URI.join(url, location).to_s, redirect_count: redirect_count + 1)
      else
        raise "Failed to fetch #{url}: HTTP #{response.code}"
      end
    end
  end
end
