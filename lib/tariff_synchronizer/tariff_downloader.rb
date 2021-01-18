module TariffSynchronizer
  # Download pending updates for TARIC, CHIEF and CDS data
  class TariffDownloader
    delegate :instrument, :subscribe, to: ActiveSupport::Notifications

    attr_reader :filename, :url, :date, :update_klass

    def initialize(filename, url, date, update_klass)
      @filename = filename
      @url = url
      @date = date
      @update_klass = update_klass
    end

    def perform
      if file_already_downloaded?
        create_entry
      else
        download_and_create_entry
      end
    end

    private

    def create_entry
      return if tariff_update.present?

      update_or_create(filename, BaseUpdate::PENDING_STATE, filesize)
      instrument('created_tariff.tariff_synchronizer', date: date, filename: filename, type: update_klass.update_type)
    end

    def file_already_downloaded?
      FileService.file_exists?(file_path)
    end

    def tariff_update
      update_klass.find(filename: filename, update_type: update_klass.name, issue_date: date)
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
      update_or_create(filename, BaseUpdate::FAILED_STATE)
      instrument('blank_update.tariff_synchronizer', date: date, url: url)
    end

    def create_record_for_exceeded_response
      update_or_create(filename, BaseUpdate::FAILED_STATE)
      instrument('retry_exceeded.tariff_synchronizer', date: date, url: url)
    end

    def create_record_for_not_found_response
      # Do not create missing record until we are sure until the next day
      return if date >= Date.current

      update_or_create(missing_update_name, BaseUpdate::MISSING_STATE)
      instrument('not_found.tariff_synchronizer', date: date, url: url)
    end

    def create_record_for_successful_response
      update_klass.validate_file!(response.content) # Validate response
      update_or_create(filename, BaseUpdate::PENDING_STATE, response.content.size)
      write_update_file(response.content)
    rescue BaseUpdate::InvalidContents => exception
      persist_exception_for_review(exception)
    end

    def update_or_create(file_name, state, file_size = nil)
      update_klass.find_or_create(filename: file_name,
                                  update_type: update_klass.name,
                                  issue_date: date)
        .update(state: state, filesize: file_size)
    end

    def write_update_file(response_body)
      FileService.write_file(file_path, response_body)
      instrument('downloaded_tariff_update.tariff_synchronizer',
                 date: date,
                 url: url,
                 type: update_klass.update_type,
                 path: file_path,
                 size: response_body.size)
    end

    def file_path
      File.join(TariffSynchronizer.root_path, update_klass.update_type.to_s, filename)
    end

    def missing_update_name
      "#{date}_#{update_klass.update_type}"
    end

    def persist_exception_for_review(exception)
      update_or_create(filename, BaseUpdate::FAILED_STATE)
        .update(exception_class: "#{exception.original.class}: #{exception.original.message}",
                exception_backtrace: exception.original.backtrace.try(:join, "\n"))
    end
  end
end
