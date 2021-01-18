module TariffSynchronizer
  # Class checks tarif update files for current and previous year
  class TaricSequenceChecker
    def initialize(with_email = false)
      @with_email = with_email
      @old_retry = TariffSynchronizer.retry_count
      @old_exception_retry = TariffSynchronizer.exception_retry_count
      @missing_updates = []
    end

    def perform
      increase_retry_limit

      interval.each do |date|
        generator = TaricFileNameGenerator.new(date)

        response = TariffUpdatesRequester.perform(generator.url)

        generator.get_info_from_response(response.content).each do |update|
          local_path = "#{TariffSynchronizer.root_path}/#{TaricUpdate.update_type}/#{update[:filename]}"
          @missing_updates << update[:filename] unless FileService.file_exists?(local_path)
        end
      end

      @missing_updates.select! { |file| file.include?('.xml') }

      if @with_email && @missing_updates.any?
        Mailer.failed_taric_sequence(@missing_updates).deliver_now
      end

      @missing_updates
    rescue Curl::Err::HostResolutionError, TariffUpdatesRequester::DownloadException
      @missing_updates
    ensure
      restore_retry_limit
    end

    private

    def interval
      today = Date.today
      end_date = today
      start_date = Date.new(today.year - 1, 1, 1)
      start_date..end_date
    end

    def increase_retry_limit
      TariffSynchronizer.retry_count = 5000
      TariffSynchronizer.exception_retry_count = 2500
    end

    def restore_retry_limit
      TariffSynchronizer.retry_count = @old_retry
      TariffSynchronizer.exception_retry_count = @old_exception_retry
    end
  end
end
