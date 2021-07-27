module TariffSynchronizer
  class Logger < ActiveSupport::LogSubscriber
    # Download all pending Taric updates
    def download(_event)
      info 'Finished downloading updates'
    end

    # Sync variables were not set correctly
    def config_error(_event)
      error 'Missing: Tariff sync enviroment variables: TARIFF_SYNC_USERNAME, TARIFF_SYNC_PASSWORD, TARIFF_SYNC_HOST and TARIFF_SYNC_EMAIL.'
    end

    # There are failed updates (can't proceed)
    def failed_updates_present(event)
      error "TariffSynchronizer found failed updates that need to be fixed before running: #{event.payload[:file_names]}"
    end

    # Apply all pending Taric updates
    def apply(event)
      info 'Finished applying updates'

      Mailer.applied(
        event.payload[:update_names],
        event.payload.fetch(:unconformant_records, []),
        event.payload.fetch(:import_warnings, []),
      ).deliver_now
    end

    def apply_lock_error(_event)
      warn 'Failed to acquire Redis lock for update application'
    end

    # Update failed to be applied
    def failed_update(event)
      error "Update failed: #{event.payload[:update]}"

      Mailer.exception(
        event.payload[:exception],
        event.payload[:update],
        event.payload[:database_queries],
      ).deliver_now
    end

    def rollback(event)
      info "Rolled back to #{event.payload[:date]}. Forced keeping records: #{!!event.payload[:keep]}"
    end

    def rollback_lock_error(event)
      warn "Failed to acquire Redis lock for rollback to #{event.payload[:date]}. Keep records: #{event.payload[:keep]}"
    end

    # Update download failed
    def failed_download(event)
      exception = event.payload[:exception]
      error "Download failed: #{exception.original}, url: #{exception.url}"
      Mailer.failed_download(exception.original, exception.url).deliver_now
    end

    # Exceeded retry count
    def retry_exceeded(event)
      warn "Download retry count exceeded for #{event.payload[:url]}"

      Mailer.retry_exceeded(event.payload[:url], event.payload[:date]).deliver_now
    end

    # Update not found
    def not_found(event)
      warn "Update NOT found for #{event.payload[:date]} at #{event.payload[:url]}"
    end

    def created_tariff(event)
      info "Created/Updated #{event.payload[:type].upcase} entry for #{event.payload[:date]} and #{event.payload[:filename]}"
    end

    # Apply TARIC update
    def apply_taric(event)
      info "Applied TARIC update #{event.payload[:filename]}"
    end

    # Apply CDS update
    def apply_cds(event)
      info "Applied CDS update #{event.payload[:filename]}"
    end

    # Query for TARIC update path
    def get_taric_update_name(event)
      info "Checking for TARIC update for #{event.payload[:date]} at #{event.payload[:url]}"
    end

    # Query for CDS update path
    def get_cds_update_name(event)
      info "Checking for CDS update for #{event.payload[:date]} at #{event.payload[:url]}"
    end

    # Query for CDS daily updates
    def get_cds_daily_updates(event)
      info "Checking for CDS daily updates for #{event.payload[:date]}"
    end

    def cds_not_found(event)
      warn "Cds daily update NOT found for #{event.payload[:date]}"
    end

    def downloaded_tariff_update(event)
      info "#{event.payload[:type].upcase} update for #{event.payload[:date]} downloaded from #{event.payload[:url]}, to #{event.payload[:path]} (size: #{event.payload[:size]})"
    end

    # Update with blank content received
    def blank_update(event)
      error "Blank update content received for #{event.payload[:date]}: #{event.payload[:url]}"

      Mailer.blank_update(event.payload[:url], event.payload[:url]).deliver_now
    end

    # Delayed update fetching
    def delay_download(event)
      info "Delaying update fetching: #{event.payload[:url]} (response code: #{event.payload[:response_code]})"
    end

    # Problems downloading
    def download_exception(event)
      info "Delaying update fetching: #{event.payload[:url]} (reason: #{event.payload[:class]})"
    end

    # Problems downloading
    def download_exception_exceeded(event)
      info "Giving up fetching: #{event.payload[:url]}, too many DownloadExceptions"
    end

    # We missed three update files in a row
    # Might be okay for Taric. This is a precautionary measure
    def missing_updates(event)
      warn "Missing #{event.payload[:count]} updates in a row for #{event.payload[:update_type].to_s.upcase}"

      Mailer.missing_updates(event.payload[:count], event.payload[:update_type].to_s).deliver_now
    end

    def perform_update(event)
      info "Processing #{event.payload[:update_type]} file: #{event.payload[:filename]}"
    end

    def rollback_update(event)
      info "Rolling back #{event.payload[:update_type].to_s.upcase} file: #{event.payload[:filename]}"
    end
  end
end

TariffSynchronizer::Logger.attach_to :tariff_synchronizer
