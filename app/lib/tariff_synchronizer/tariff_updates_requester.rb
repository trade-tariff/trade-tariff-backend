module TariffSynchronizer
  # The server in question may respond with 403 from time to time so keep retrying
  # until it returns either 200 or 404 or retry count limit is reached
  class TariffUpdatesRequester
    class DownloadException < StandardError
      attr_reader :url, :original

      def initialize(url, original)
        super('TariffSynchronizer::TariffUpdatesRequester::DownloadException')

        @url = url
        @original = original
      end
    end

    def initialize(url)
      @url = url
      @retry_count = TariffSynchronizer.retry_count
      @exception_retry_count = TariffSynchronizer.exception_retry_count
    end

    def self.perform(url)
      new(url).perform
    end

    def perform
      loop do
        response = send_request

        if response.terminated?
          return response
        elsif @retry_count.zero?
          response.retry_count_exceeded!
          return response
        else
          @retry_count -= 1
          Rails.logger.info "Delaying update fetching: #{@url} (response code: #{response.response_code})"
          sleep TariffSynchronizer.request_throttle
        end
      rescue DownloadException => e
        Rails.logger.info "Delaying update fetching: #{@url} (reason: #{e.original.class})"
        if @exception_retry_count.zero?
          Rails.logger.info "Giving up fetching: #{@url}, too many DownloadExceptions"
          raise
        else
          @exception_retry_count -= 1
          sleep TariffSynchronizer.request_throttle
        end
      end
    end

    private

    def send_request
      uri = URI(@url)

      client = Faraday.new(uri.host) do |conn|
        if TradeTariffBackend.xi?
          conn.set_basic_auth(TaricSynchronizer.username, TaricSynchronizer.password)
        end
      end

      faraday_response = client.get(uri)

      Response.new(faraday_response.status, faraday_response.body)
    rescue Faraday::Error => e
      raise DownloadException.new(@url, e)
    end
  end
end
