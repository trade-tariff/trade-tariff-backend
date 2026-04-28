module TariffSynchronizer
  # The server in question may respond with 403 from time to time. Rather than
  # sleeping in-thread, callers should catch RetriableDownloadError and
  # reschedule via Sidekiq so worker threads are not held while waiting.
  class TariffUpdatesRequester
    class DownloadException < StandardError
      attr_reader :url, :original

      def initialize(url, original)
        super('TariffSynchronizer::TariffUpdatesRequester::DownloadException')

        @url = url
        @original = original
      end
    end

    class RetriableDownloadError < StandardError
      attr_reader :url

      def initialize(url)
        super('TariffSynchronizer::TariffUpdatesRequester::RetriableDownloadError')

        @url = url
      end
    end

    def initialize(url)
      @url = url
    end

    def self.perform(url)
      new(url).perform
    end

    def perform
      response = send_request

      return response if response.terminated?

      Instrumentation.download_retried(
        url: @url,
        attempt: 1,
        reason: "response_code_#{response.response_code}",
      )
      raise RetriableDownloadError, @url
    rescue DownloadException => e
      Instrumentation.download_retried(
        url: @url,
        attempt: 1,
        reason: e.original.class.name,
      )
      raise RetriableDownloadError, @url
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
