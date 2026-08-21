require 'net/http'

module VatGuidance
  class ContextGraphSource
    DOCUMENT_PATHS = {
      '701-23' => '/guidance/protective-equipment-and-vat-notice-70123',
      '701-14' => '/guidance/food-products-and-vat-notice-70114',
      '709-1' => '/guidance/catering-takeaway-food-and-vat-notice-7091',
    }.freeze

    def initialize(source_directory: nil)
      @source_directory = source_directory.presence
    end

    def call
      DOCUMENT_PATHS.map do |key, path|
        @source_directory ? read_snapshot(key) : fetch_content_api(path)
      end
    end

  private

    def read_snapshot(key)
      JSON.parse(File.read(File.join(@source_directory, "vat-#{key}.json")))
    end

    def fetch_content_api(path)
      uri = URI("https://www.gov.uk/api/content#{path}")
      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: 10,
        read_timeout: 30,
      ) { |http| http.get(uri.request_uri, 'Accept' => 'application/json') }
      raise "GET #{uri} failed: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end
  end
end
