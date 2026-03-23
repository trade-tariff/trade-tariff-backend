module Reporting
  class BackfillDifferencesReports
    LOOKBACK_DAYS = 30
    COVERAGE_WINDOW_DAYS = 7
    CONTENT_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'.freeze
    DIFFERENCES_KEY_PATTERN = %r{\Auk/reporting/(\d{4})/(\d{2})/(\d{2})/differences_(\d{4})-(\d{2})-(\d{2})\.xlsx\z}

    def initialize(today: Time.zone.today, dry_run: false, send_email: true, mailer: ReportsMailer, bucket: Reporting::Differences.bucket, existing_reports_fetcher: nil, report_body_fetcher: nil)
      @today = today.to_date
      @dry_run = dry_run
      @send_email = send_email
      @mailer = mailer
      @bucket = bucket
      @existing_reports_fetcher = existing_reports_fetcher
      @report_body_fetcher = report_body_fetcher
    end

    def call
      summary = {
        uploaded: [],
        emailed: [],
        email_skipped: [],
        planned_uploads: [],
        planned_emails: [],
      }

      missing_mondays.each do |monday|
        covered = rerun_covered?(monday)

        if dry_run
          summary[:planned_uploads] << monday
          summary[:planned_emails] << monday if send_email && !covered
          summary[:email_skipped] << monday if covered || !send_email
          next
        end

        upload_copy(monday)
        summary[:uploaded] << monday

        if covered || !send_email
          summary[:email_skipped] << monday
          next
        end

        mailer.differences(email_report_for(monday)).deliver_now
        summary[:emailed] << monday
      end

      summary
    end

    private

    ReportSource = Struct.new(:date, :key, keyword_init: true)

    class WorkbookWrapper
      def initialize(data)
        @data = data
      end

      def read_string
        @data
      end
    end

    class EmailReport
      attr_reader :as_of, :workbook

      def initialize(as_of:, workbook_data:)
        @as_of = as_of.to_date.iso8601
        @workbook = WorkbookWrapper.new(workbook_data)
      end

      def sections
        Reporting::Differences::Renderers::Overview::OVERVIEW_SECTION_CONFIG.keys.map do |section|
          worksheets = Reporting::Differences::Renderers::Overview::OVERVIEW_SECTION_CONFIG.dig(section, :worksheets).map do |worksheet, config|
            OpenStruct.new(
              worksheet:,
              worksheet_name: config[:worksheet_name],
              subtext: config[:description].sub('as_of', as_of.to_date.to_fs(:govuk)),
            )
          end

          OpenStruct.new(section:, worksheets:)
        end
      end

      def uk_commodities_link
        Reporting::Commodities.get_uk_link_today
      end

      def xi_commodities_link
        Reporting::Commodities.get_xi_link_today
      end

      def uk_supplementary_units_link
        Reporting::SupplementaryUnits.get_uk_link_today
      end

      def xi_supplementary_units_link
        Reporting::SupplementaryUnits.get_xi_link_today
      end
    end

    attr_reader :today, :dry_run, :send_email, :mailer, :bucket, :existing_reports_fetcher, :report_body_fetcher

    def missing_mondays
      monday_dates.reject { |date| existing_report_dates.include?(date) }
    end

    def rerun_covered?(monday)
      coverage_range = (monday + 1.day)..(monday + COVERAGE_WINDOW_DAYS.days)
      existing_report_dates.any? { |date| coverage_range.cover?(date) && !date.monday? }
    end

    def monday_dates
      ((today - LOOKBACK_DAYS.days)..(today - 1.day)).select(&:monday?)
    end

    def latest_report
      @latest_report ||= existing_reports.max_by(&:date)
    end

    def latest_report_body
      @latest_report_body ||= if report_body_fetcher
                                report_body_fetcher.call(latest_report.key)
                              else
                                Reporting.get_published(latest_report.key)
                              end
    end

    def email_report_for(date)
      EmailReport.new(as_of: date, workbook_data: latest_report_body)
    end

    def existing_report_dates
      @existing_report_dates ||= existing_reports.map(&:date).to_set
    end

    def existing_reports
      @existing_reports ||= begin
        reports = existing_reports_fetcher ? existing_reports_fetcher.call : fetch_existing_reports
        reports.map { |report| ReportSource.new(**report) }
      end
    end

    def fetch_existing_reports
      continuation_token = nil
      reports = []

      loop do
        response = bucket.client.list_objects_v2(
          bucket: bucket.name,
          prefix: 'uk/reporting/',
          continuation_token: continuation_token,
        )

        response.contents.each do |object|
          date = extract_date(object.key)
          reports << { date:, key: object.key } if date
        end

        break unless response.is_truncated

        continuation_token = response.next_continuation_token
      end

      reports
    end

    def upload_copy(date)
      bucket.object(object_key(date)).put(
        body: latest_report_body,
        content_type: CONTENT_TYPE,
      )
    end

    def object_key(date)
      "uk/reporting/#{date.strftime('%Y/%m/%d')}/differences_#{date}.xlsx"
    end

    def extract_date(key)
      match = DIFFERENCES_KEY_PATTERN.match(key)
      return unless match

      Date.new(match[4].to_i, match[5].to_i, match[6].to_i)
    end
  end
end
