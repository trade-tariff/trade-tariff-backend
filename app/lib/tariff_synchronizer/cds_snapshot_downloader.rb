module TariffSynchronizer
  class CdsSnapshotDownloader < CdsUpdateDownloader
    ANNUAL_FILE_PATTERN = /tariff_yearlyExtract_v1_(\d{4}0101)T\d{6}\.gzip/
    MONTHLY_FILE_PATTERN = /tariff_monthlyExtract_v1_(\d{8})T\d{6}\.gzip/

    attr_reader :request_date

    def initialize(request_date)
      @request_date = request_date
    end

    def perform
      log_request

       if request_date.month == 1
         file = fetch_file('TARIFF-ANNUAL', ANNUAL_FILE_PATTERN, request_date.strftime('%Y%m%d'))
         if file.present?
           TariffDownloader.new(file['filename'], file['downloadURL'], request_date, TariffSynchronizer::CdsSnapshotUpdate).perform
         end
       end

      last_day_of_previous_month = request_date.prev_month.end_of_month.strftime('%Y%m%d')
      file = fetch_file('TARIFF-MONTHLY', MONTHLY_FILE_PATTERN, last_day_of_previous_month)
      if file.present?
        TariffDownloader.new(file['filename'], file['downloadURL'], request_date, TariffSynchronizer::CdsSnapshotUpdate).perform
      end
    end

    private

    def fetch_file(file_type, pattern, target_date)
      snapshot_files = JSON.parse(response(file_type).body)
      return if snapshot_files.empty?

      snapshot_files.find do |f|
        match = f['filename'].match(pattern)
        match && match[1] == target_date
      end
    end

    def log_request
      Rails.logger.info "Checking for CDS snapshot for #{request_date}"
    end
  end
end
