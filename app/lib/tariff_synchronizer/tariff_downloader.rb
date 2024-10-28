module TariffSynchronizer
  # Download pending updates for TARIC and CDS data
  class TariffDownloader
    TariffDownloaderZipError = Class.new(StandardError)

    ZIP_SIGNATURE = "\x50\x4B\x03\x04".freeze
    GZIP_SIGNATURE = "\x1F\x8B\x08\x00".freeze

    delegate :instrument, :subscribe, to: ActiveSupport::Notifications

    attr_reader :filename, :url, :date, :update_klass, :success
    alias_method :success?, :success

    def initialize(filename, url, date, update_klass)
      @filename = filename
      @url = url
      @date = date
      @update_klass = update_klass
      @success = false
    end

    def perform
      if file_already_downloaded?
        puts('already downloaded')
        create_entry
      else

        puts('Not already downloaded')
        download_and_create_entry
      end
    rescue StandardError => e
      persist_exception_for_review(e)
    end

    private

    def create_entry
      return if tariff_update.present?

      @success = true

      update_or_create(filename, BaseUpdate::PENDING_STATE, filesize)
      Rails.logger.info("Created/Updated #{update_klass.update_type.upcase} entry for #{date} and #{filename}")
    end

    def file_already_downloaded?
      FileService.file_exists?(file_path)
    end

    def tariff_update
      update_klass.find(filename:, update_type: update_klass.name, issue_date: date)
    end

    def filesize
      @filesize ||= FileService.file_size(file_path)
    end

    def response
      @response ||= TariffUpdatesRequester.perform(url)
    end

    def download_and_create_entry
      send("create_record_for_#{response.state}_response")
    end

    def create_record_for_empty_response
      puts('called create_record_for_empty_response')
      update_or_create(filename, BaseUpdate::FAILED_STATE)
      TariffLogger.blank_update(date:, url:)
    end

    def create_record_for_exceeded_response
      puts('called reate_record_for_exceeded_response')
      update_or_create(filename, BaseUpdate::FAILED_STATE)
      TariffLogger.retry_exceeded(date, url)
    end

    # We do not create records for missing updates
    def create_record_for_not_found_response
      puts('called create_record_for_not_found_response')
    end

    def create_record_for_successful_response
      puts('create_record_for_successful_response')
      update_or_create(filename, BaseUpdate::PENDING_STATE, response.content.size)
      write_update_file(response.content)
      @success = true
    end

    def update_or_create(filename, state, filesize = nil)
      update_klass
        .find_or_create(filename:, update_type: update_klass.name, issue_date:)
        .update(state:, filesize:)
    end

    def write_update_file(response_body)
      if should_write_file?(response_body)
        FileService.write_file(file_path, response_body)
        puts('wrote file')
        Rails.logger.info("#{update_type.upcase} update for #{date} downloaded from #{url}, to #{file_path} (size: #{response_body.size})")
      else
        puts("didn't write file")
        persist_exception_for_review(TariffDownloaderZipError.new('Response was not a zip file. Skipping persistence'))
      end
    end

    def file_path
      File.join(TariffSynchronizer.root_path, update_type.to_s, filename)
    end

    def persist_exception_for_review(exception)
      update_or_create(filename, BaseUpdate::FAILED_STATE)
        .update(exception_class: "#{exception.class}: #{exception.message}",
                exception_backtrace: exception.backtrace.try(:join, "\n"))
    end

    def should_write_file?(response_body)
      # If it's a TaricUpdate, write the file
      return true if update_klass == TariffSynchronizer::TaricUpdate

      # Check if it's a ZIP or GZIP file
      return true if zip_file?(response_body) || gzip_file?(response_body)

      # If neither, don't write the file
      false
    end

    def zip_file?(content)
      # Get the first four bytes as binary
      start_bytes = content[0, 4]

      # Compare byte-by-byte
      if start_bytes.bytes == ZIP_SIGNATURE.bytes
        puts "It's a ZIP file"
        true
      else
        puts "It's not a ZIP file"
        false
      end
    end

    def gzip_file?(content)
      # Get the first four bytes as binary
      start_bytes = content[0, 4]

      # Log the length of both byte arrays
      puts "GZIP_SIGNATURE length: #{GZIP_SIGNATURE.bytes.length}"
      puts "start_bytes length: #{start_bytes.bytes.length}"

      # Compare byte-by-byte
      if start_bytes.bytes == GZIP_SIGNATURE.bytes
        puts "It's a GZIP file"
        true
      else
        puts "It's not a GZIP file"
        false
      end
    end

    delegate :update_type, to: :update_klass

    alias_method :issue_date, :date
  end
end
