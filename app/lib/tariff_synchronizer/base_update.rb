module TariffSynchronizer
  class BaseUpdate < Sequel::Model(:tariff_updates)
    DOWNLOAD_FROM = 20.days

    # Used for TARIC updates only.
    one_to_many :presence_errors, class: TariffUpdatePresenceError, key: :tariff_update_filename
    # Used for CDS updates only.
    one_to_many :cds_errors, class: TariffUpdateCdsError, key: :tariff_update_filename

    def presence_error_ids
      presence_errors.pluck(:id)
    end

    plugin :timestamps
    plugin :eager_each
    plugin :timestamps
    plugin :single_table_inheritance, :update_type
    plugin :validation_class_methods

    APPLIED_STATE = 'A'.freeze
    PENDING_STATE = 'P'.freeze
    FAILED_STATE  = 'F'.freeze
    MISSING_STATE = 'M'.freeze

    unrestrict_primary_key

    validates do
      presence_of :filename, :issue_date
    end

    dataset_module do
      def by_filename(filename_without_suffix)
        filename = if TradeTariffBackend.uk?
                     "#{filename_without_suffix}.gzip"
                   else
                     "#{filename_without_suffix}.xml"
                   end

        where(filename:).take
      end

      def applied
        filter(state: APPLIED_STATE)
      end

      def pending
        where(state: PENDING_STATE)
      end

      def pending_at(day)
        where(issue_date: day, state: PENDING_STATE)
      end

      def missing
        where(state: MISSING_STATE)
      end

      def with_issue_date(date)
        where(issue_date: date)
      end

      def failed
        where(state: FAILED_STATE)
      end

      def pending_applied_or_failed
        where(state: [PENDING_STATE, APPLIED_STATE, FAILED_STATE])
      end

      def pending_or_failed
        where(state: [PENDING_STATE, FAILED_STATE])
      end

      def applied_or_failed
        where(state: [APPLIED_STATE, FAILED_STATE])
      end

      def oldest_pending
        pending.ascending.first
      end

      def most_recent_pending
        pending.descending.first
      end

      def most_recent_applied
        applied.descending.first
      end

      def most_recent_failed
        failed.descending.first
      end

      def ascending
        order(Sequel.asc(:issue_date))
      end

      def descending
        order(Sequel.desc(:issue_date))
      end

      def latest_applied_of_both_kinds
        exclude(update_type: 'TariffSynchronizer::ChiefUpdate')
          .distinct(:update_type)
          .select(Sequel.expr(:tariff_updates).*)
          .descending.applied.order_prepend(:update_type)
      end
    end

    def applied?
      state == APPLIED_STATE
    end

    def pending?
      state == PENDING_STATE
    end

    def missing?
      state == MISSING_STATE
    end

    def failed?
      state == FAILED_STATE
    end

    def mark_as_applied
      update(state: APPLIED_STATE, applied_at: Time.zone.now, last_error: nil, last_error_at: nil, exception_backtrace: nil, exception_class: nil)
    end

    def mark_as_failed
      update(state: FAILED_STATE)
    end

    def mark_as_pending
      update(state: PENDING_STATE)
    end

    def clear_applied_at
      update(applied_at: nil)
    end

    def file_path
      "#{TariffSynchronizer.root_path}/#{self.class.update_type}/#{filename}"
    end

    # can cause a delay as we a requesting S3 bucket for each update
    # TODO: is it possible to cache it? need to investigate
    def file_presigned_url
      TariffSynchronizer::FileService.file_presigned_url(file_path)
    end

    def import!
      raise NotImplementedError
    end

    def cache_key_with_version
      [
        'tariff-update',
        filename,
        update_type,
        state,
        applied_at.iso8601,
      ].map(&:to_s).join('-')
    end

    class << self
      delegate :instrument, to: ActiveSupport::Notifications

      def sync(initial_date:)
        applicable_download_date_range(initial_date:).each { |date| download(date) }

        notify_about_missing_updates if last_updates_are_missing?
      end

      def update_type
        raise 'Update Type should be specified in inheriting class'
      end

      def applicable_download_date_range(initial_date:)
        download_start_date(initial_date:)..download_end_date
      end

      private

      def download_end_date
        Time.zone.today
      end

      def download_start_date(initial_date:)
        if pending_applied_or_failed.count.zero?
          initial_date
        else
          last_download = oldest_pending || most_recent_applied || most_recent_failed

          [last_download.issue_date, DOWNLOAD_FROM.ago.to_date].min
        end
      end

      def last_updates_are_missing?
        holidays = BankHolidays.last(TariffSynchronizer.warning_day_count)
        descending.exclude(issue_date: holidays)
          .first.try(:missing?)
      end

      def notify_about_missing_updates
        TariffLogger.missing_updates(update_type:, count: TariffSynchronizer.warning_day_count)
      end
    end
  end
end
