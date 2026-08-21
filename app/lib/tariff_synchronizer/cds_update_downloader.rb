module TariffSynchronizer
  class CdsUpdateDownloader
    class AuthorisationError < StandardError; end
    class ListDownloadFailedError < StandardError; end

    DOWNLOAD_FROM = BaseUpdate::DOWNLOAD_FROM

    delegate :instrument, :subscribe, to: ActiveSupport::Notifications

    class << self
      def download(initial_date: CdsSynchronizer.initial_update_date)
        unless sync_variables_set?
          Instrumentation.sync_run_failed(
            phase: 'download',
            error_class: 'ConfigurationError',
            error_message: 'Missing: Tariff sync environment variables: HMRC_API_HOST, HMRC_CLIENT_ID and HMRC_CLIENT_SECRET.',
          )
          return
        end

        TradeTariffBackend.with_redis_lock do
          Instrumentation.lock_acquired(phase: 'download')

          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          sync(initial_date:)

          duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
          Instrumentation.download_completed(
            duration_ms:,
            files_count: CdsUpdate.pending.count,
          )
        end
      end

      def sync(initial_date:)
        applicable_download_date_range(initial_date:).each { |date| new(date).perform }
      end

      # CDS files are published with a one-day lag; "today's" file uses yesterday's issue date.
      def downloaded_todays_file?
        CdsUpdate.with_issue_date(Time.zone.yesterday).count.positive?
      end

      def applicable_download_date_range(initial_date:)
        download_start_date(initial_date:)..download_end_date
      end

    private

      def sync_variables_set?
        ENV['HMRC_API_HOST'].present? && ENV['HMRC_CLIENT_ID'].present? && ENV['HMRC_CLIENT_SECRET'].present?
      end

      def download_end_date
        Time.zone.today
      end

      def download_start_date(initial_date:)
        if CdsUpdate.pending_applied_or_failed.count.zero?
          initial_date
        else
          last_download = CdsUpdate.oldest_pending || CdsUpdate.most_recent_applied || CdsUpdate.most_recent_failed

          [last_download.issue_date, DOWNLOAD_FROM.ago.to_date].min
        end
      end
    end

    attr_reader :request_date

    def initialize(request_date)
      @request_date = request_date
    end

    def perform
      Instrumentation.download_started(filename: "cds_daily_list_#{request_date.iso8601}")

      # CDS updates are published with a few days delay so we should check past dates.
      range = ((request_date - 5.days)..request_date).to_a
      daily_files = JSON.parse(response.body)

      return if daily_files.empty?

      range.each do |date|
        file = daily_files.find { |df| df['filename'][23..30] == date.strftime('%Y%m%d') }
        next unless file

        TariffDownloader.new(file['filename'], file['downloadURL'], date, TariffSynchronizer::CdsUpdate).perform
      end
    end

  private

    # Example:
    # { "filename"=>"tariff_dailyExtract_v1_20191009T235959.gzip",
    #   "downloadURL"=>"https://sdes.hmrc.gov.uk/api-download/156ec583-9245-484a-9f91-3919493a047d",
    #   "fileSize"=>478 }
    # downloadURL contains gzip file with an xml file inside.
    def response
      @response = begin
        uri = URI.join(ENV['HMRC_API_HOST'], '/bulk-data-download/list/TARIFF-DAILY')
        https = Net::HTTP.new(uri.host, uri.port)
        https.use_ssl = true
        request = Net::HTTP::Get.new(uri.request_uri)
        request['User-Agent'] = 'Trade Tariff Backend'
        request['Accept'] = 'application/vnd.hmrc.1.0+json'
        request['Authorization'] = "Bearer #{access_token}"
        https.request(request)
      end

      if @response.code == '200' && @response.body.present?
        @response
      else
        raise ListDownloadFailedError, @response.code
      end
    end

    def access_token
      uri = URI.join(ENV['HMRC_API_HOST'], '/oauth/token')
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      request = Net::HTTP::Post.new(uri.request_uri)
      request.set_form_data(
        client_id: ENV['HMRC_CLIENT_ID'],
        client_secret: ENV['HMRC_CLIENT_SECRET'],
        grant_type: 'client_credentials',
      )

      response = https.request(request)

      if response.code == '200'
        JSON.parse(response.body)['access_token']
      else
        raise AuthorisationError, response.body
      end
    end
  end
end
