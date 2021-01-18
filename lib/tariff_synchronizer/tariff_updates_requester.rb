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
        begin
          response = send_request

          if response.terminated?
            return response
          elsif @retry_count == 0
            response.retry_count_exceeded!
            return response
          else
            @retry_count -= 1
            ActiveSupport::Notifications.instrument('delay_download.tariff_synchronizer', url: @url, response_code: response.response_code)
            sleep TariffSynchronizer.request_throttle
          end
        rescue DownloadException => exception
          ActiveSupport::Notifications.instrument('download_exception.tariff_synchronizer', url: @url, class: exception.original.class)
          if @exception_retry_count == 0
            ActiveSupport::Notifications.instrument('download_exception_exceeded.tariff_synchronizer', url: @url)
            raise
          else
            @exception_retry_count -= 1
            sleep TariffSynchronizer.request_throttle
          end
        end
      end
    end

  private

    def send_request
      begin
        crawler = Curl::Easy.new(@url)
        crawler.ssl_verify_peer = false
        crawler.ssl_verify_host = false
        # Add basic auth if it's TARIC or CHIEF, and skip it for CDS updates
        if URI(@url).host == URI(ENV['TARIFF_SYNC_HOST']).host
          crawler.http_auth_types = :basic
          crawler.username = TariffSynchronizer.username
          crawler.password = TariffSynchronizer.password
        end
        crawler.perform
      rescue Curl::Err::HostResolutionError,
             Curl::Err::ConnectionFailedError,
             Curl::Err::SSLConnectError,
             Curl::Err::PartialFileError => exception
        # NOTE could be a glitch in curb because it throws HostResolutionError
        # occasionally without any reason.
        raise DownloadException.new(@url, exception)
      end

      Response.new(crawler.response_code, crawler.body_str)
    end
  end
end
