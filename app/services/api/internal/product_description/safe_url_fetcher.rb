require 'ipaddr'
require 'uri'

module Api
  module Internal
    module ProductDescription
      class SafeUrlFetcher
        class FetchError < StandardError
          attr_reader :title, :reason

          def initialize(title, detail, reason: nil)
            @title = title
            @reason = reason
            super(detail)
          end

          def http_status?
            reason == :http_status
          end
        end

        ALLOWED_CONTENT_TYPES = [
          'text/html',
          'application/xhtml+xml',
          'text/plain',
        ].freeze
        UNSAFE_IP_RANGES = [
          '0.0.0.0/8',
          '10.0.0.0/8',
          '100.64.0.0/10',
          '127.0.0.0/8',
          '169.254.0.0/16',
          '172.16.0.0/12',
          '192.0.0.0/24',
          '192.0.2.0/24',
          '192.168.0.0/16',
          '198.18.0.0/15',
          '198.51.100.0/24',
          '203.0.113.0/24',
          '224.0.0.0/4',
          '240.0.0.0/4',
          '255.255.255.255/32',
          '::/128',
          '::1/128',
          'fc00::/7',
          'fe80::/10',
          'ff00::/8',
          '2001:db8::/32',
        ].map { |range| IPAddr.new(range) }.freeze

        def self.call(url)
          new(url).call
        end

        def initialize(url)
          @url = url.to_s
        end

        def call
          fetch(parse_and_validate_url(@url), redirect_count: 0)
        end

        private

        def fetch(uri, redirect_count:)
          validate_resolved_addresses!(uri.host)

          streamed_body = +''
          response = connection.get(uri.to_s) do |request|
            request.options.on_data = proc do |chunk, _received_bytes, _env|
              append_body_chunk(streamed_body, chunk)
            end
          end

          if redirect?(response)
            raise FetchError.new('Too many redirects', 'Too many redirects') if redirect_count >= max_redirects

            location = response.headers['location'] || response.headers['Location']
            raise FetchError.new('Invalid URL', 'Redirect response did not include a location') if location.blank?

            return fetch(parse_and_validate_url(URI.join(uri.to_s, location).to_s), redirect_count: redirect_count + 1)
          end

          raise FetchError.new('Fetch failed', "URL returned HTTP #{response.status}", reason: :http_status) unless response.success?

          content_type = response.headers['content-type'] || response.headers['Content-Type'] || ''
          raise FetchError.new('Unsupported content type', 'Unsupported content type') unless allowed_content_type?(content_type)

          FetchedPage.new(final_url: uri.to_s, content_type:, body: response_body(response, streamed_body))
        rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
          raise FetchError.new('Fetch failed', e.message)
        end

        def append_body_chunk(body, chunk)
          return if body.bytesize >= max_response_bytes

          body << chunk.byteslice(0, max_response_bytes - body.bytesize).to_s
        end

        def response_body(response, streamed_body)
          body = streamed_body.presence || response.body.to_s
          return body unless body.bytesize > max_response_bytes

          body.byteslice(0, max_response_bytes).to_s
        end

        def parse_and_validate_url(raw_url)
          raise FetchError.new('Invalid URL', 'Url is required') if raw_url.blank?

          uri = URI.parse(raw_url)
          raise FetchError.new('Invalid URL', 'Only https URLs are supported') unless uri.is_a?(URI::HTTPS)
          raise FetchError.new('Invalid URL', 'URL host is required') if uri.host.blank?
          raise FetchError.new('Invalid URL', 'URL credentials are not supported') if uri.user.present? || uri.password.present?

          uri
        rescue URI::InvalidURIError
          raise FetchError.new('Invalid URL', 'URL is invalid')
        end

        def validate_resolved_addresses!(host)
          addresses = Addrinfo.getaddrinfo(host, nil)
          raise FetchError.new('Unsafe URL', 'URL resolves to an unsafe address') if addresses.empty?

          addresses.each do |address|
            ip = IPAddr.new(address.ip_address)
            raise FetchError.new('Unsafe URL', 'URL resolves to an unsafe address') if unsafe_ip?(ip)
          end
        rescue SocketError
          raise FetchError.new('Fetch failed', 'URL host could not be resolved')
        end

        def unsafe_ip?(ip)
          UNSAFE_IP_RANGES.any? { |range| range.include?(ip) }
        end

        def redirect?(response)
          response.status.between?(300, 399)
        end

        def allowed_content_type?(content_type)
          media_type = content_type.to_s.split(';').first.to_s.strip.downcase
          ALLOWED_CONTENT_TYPES.include?(media_type)
        end

        def max_response_bytes
          AdminConfiguration.integer_value('product_description_max_response_bytes')
        end

        def max_redirects
          AdminConfiguration.integer_value('product_description_max_redirects')
        end

        def open_timeout
          AdminConfiguration.integer_value('product_description_open_timeout_seconds')
        end

        def read_timeout
          AdminConfiguration.integer_value('product_description_read_timeout_seconds')
        end

        def connection
          Faraday.new do |faraday|
            faraday.adapter Faraday.default_adapter
            faraday.headers['User-Agent'] = TradeTariffBackend.user_agent
            faraday.options.open_timeout = open_timeout
            faraday.options.timeout = read_timeout
          end
        end
      end
    end
  end
end
