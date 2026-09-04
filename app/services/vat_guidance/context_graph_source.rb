require 'net/http'
require 'nokogiri'

module VatGuidance
  class ContextGraphSource
    class FetchError < StandardError; end

    Result = Data.define(:payloads, :failures, :path_aliases, :root_paths)

    GOVUK_HOST = 'www.gov.uk'.freeze
    MAX_REFERENCE_DEPTH = 1
    DOCUMENT_PATHS = {
      '701-23' => '/guidance/protective-equipment-and-vat-notice-70123',
      '701-14' => '/guidance/food-products-and-vat-notice-70114',
      '709-1' => '/guidance/catering-takeaway-food-and-vat-notice-7091',
      '744-c' => '/guidance/ships-aircraft-and-associated-services-notice-744c',
    }.freeze

    def initialize(source_directory: nil)
      @source_directory = source_directory.presence
    end

    def call
      @source_directory ? read_snapshots : fetch_source_graph
    end

  private

    def fetch_source_graph
      queue = DOCUMENT_PATHS.values.map { |path| [path, 0] }
      seen_paths = Set.new
      payloads_by_path = {}
      failures = {}
      path_aliases = {}

      until queue.empty?
        requested_path, depth = queue.shift
        next unless seen_paths.add?(requested_path)

        begin
          payload = fetch_content_api(requested_path)
          canonical_path = payload.fetch('base_path')
          path_aliases[requested_path] = canonical_path if requested_path != canonical_path
          payloads_by_path[canonical_path] ||= payload
          next unless depth < MAX_REFERENCE_DEPTH

          reference_paths(payload).each { |path| queue << [path, depth + 1] }
        rescue FetchError, JSON::ParserError, KeyError => e
          raise if depth.zero?

          failures[requested_path] = "#{e.class}: #{e.message}"
        end
      end

      Result.new(
        payloads: payloads_by_path.values,
        failures:,
        path_aliases:,
        root_paths: DOCUMENT_PATHS.values,
      )
    end

    def read_snapshots
      root_files = DOCUMENT_PATHS.keys.map do |key|
        File.expand_path(File.join(@source_directory, "vat-#{key}.json"))
      end
      snapshot_files = (root_files + Dir[File.join(@source_directory, '*.json')]).uniq
      payloads = snapshot_files.map { |path| JSON.parse(File.read(path)) }

      Result.new(
        payloads:,
        failures: {},
        path_aliases: {},
        root_paths: DOCUMENT_PATHS.values,
      )
    end

    def reference_paths(payload)
      body = payload.dig('details', 'body').to_s

      Nokogiri::HTML.fragment(body).css('a[href]').filter_map { |link| official_path(link['href']) }.uniq
    end

    def official_path(href)
      uri = URI.parse(href.to_s.strip)
      return uri.path if uri.host == GOVUK_HOST && uri.path.present?

      uri.path if uri.host.nil? && uri.path.to_s.start_with?('/')
    rescue URI::InvalidURIError
      nil
    end

    def fetch_content_api(path, redirects_remaining: 3)
      uri = URI("https://www.gov.uk/api/content#{path}")
      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: 5,
        read_timeout: 15,
      ) { |http| http.get(uri.request_uri, 'Accept' => 'application/json') }

      if response.is_a?(Net::HTTPRedirection)
        raise FetchError, "GET #{uri} exceeded the redirect limit" if redirects_remaining.zero?

        redirected_uri = uri.merge(response.fetch('location'))
        unless redirected_uri.host == GOVUK_HOST && redirected_uri.path.start_with?('/api/content/')
          raise FetchError, "GET #{uri} redirected outside the GOV.UK Content API"
        end

        redirected_path = redirected_uri.path.delete_prefix('/api/content')
        return fetch_content_api(redirected_path, redirects_remaining: redirects_remaining - 1)
      end

      raise FetchError, "GET #{uri} failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue SystemCallError, SocketError, Timeout::Error, OpenSSL::SSL::SSLError, EOFError => e
      raise FetchError, "GET #{uri} failed: #{e.class}: #{e.message}"
    end
  end
end
