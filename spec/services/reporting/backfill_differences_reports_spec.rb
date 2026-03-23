RSpec.describe Reporting::BackfillDifferencesReports do
  describe '#call' do
    def build_service(today:, existing_reports:, fetched_bodies:, dry_run: false, send_email: true, mailer: nil, bucket: nil)
      described_class.new(
        today:,
        dry_run:,
        send_email:,
        mailer: mailer || class_double(ReportsMailer, differences: instance_double(ActionMailer::MessageDelivery, deliver_now: true)),
        bucket: bucket || instance_double(Aws::S3::Bucket, object: instance_double(Aws::S3::Object, put: true)),
        existing_reports_fetcher: -> { existing_reports },
        report_body_fetcher: ->(key) { fetched_bodies.fetch(key) },
      )
    end

    def base_existing_reports(latest_date:, latest_key:)
      [
        { date: Date.new(2026, 3, 2), key: 'uk/reporting/2026/03/02/differences_2026-03-02.xlsx' },
        { date: Date.new(2026, 3, 9), key: 'uk/reporting/2026/03/09/differences_2026-03-09.xlsx' },
        { date: Date.new(2026, 3, 16), key: 'uk/reporting/2026/03/16/differences_2026-03-16.xlsx' },
        { date: latest_date, key: latest_key },
      ]
    end

    it 'uploads a copy of the latest workbook for a missing Monday' do
      latest_key = 'uk/reporting/2026/03/19/differences_2026-03-19.xlsx'
      latest_body = 'latest-xlsx-data'
      bucket = instance_double(Aws::S3::Bucket)
      target_object = instance_double(Aws::S3::Object, put: true)
      allow(bucket).to receive(:object).and_return(target_object)
      service = build_service(
        today: Date.new(2026, 3, 20),
        existing_reports: base_existing_reports(latest_date: Date.new(2026, 3, 19), latest_key:).reject { |report| report[:date] == Date.new(2026, 2, 23) },
        fetched_bodies: { latest_key => latest_body },
        bucket:,
      )

      summary = service.call

      expect(bucket).to have_received(:object).with('uk/reporting/2026/02/23/differences_2026-02-23.xlsx')
      expect(target_object).to have_received(:put).with(
        body: latest_body,
        content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      )
      expect(summary[:uploaded]).to eq([Date.new(2026, 2, 23)])
    end

    it 'emails the latest report for an uncovered missing Monday by default' do
      latest_key = 'uk/reporting/2026/03/19/differences_2026-03-19.xlsx'
      latest_body = 'latest-xlsx-data'
      message = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
      mailer = class_double(ReportsMailer, differences: message)
      service = build_service(
        today: Date.new(2026, 3, 20),
        existing_reports: base_existing_reports(latest_date: Date.new(2026, 3, 19), latest_key:).reject { |report| report[:date] == Date.new(2026, 2, 23) },
        fetched_bodies: { latest_key => latest_body },
        mailer:,
      )

      service.call

      expect(mailer).to have_received(:differences) do |report|
        expect(report.as_of).to eq('2026-02-23')
        expect(report.workbook.read_string).to eq(latest_body)
      end
      expect(message).to have_received(:deliver_now)
    end

    it 'emails each missing Monday using that Monday as the report date' do
      latest_key = 'uk/reporting/2026/03/19/differences_2026-03-19.xlsx'
      latest_body = 'latest-xlsx-data'
      message = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
      emailed_reports = []
      mailer = class_double(ReportsMailer)
      allow(mailer).to receive(:differences) do |report|
        emailed_reports << report
        message
      end
      service = build_service(
        today: Date.new(2026, 3, 20),
        existing_reports: [
          { date: Date.new(2026, 3, 9), key: 'uk/reporting/2026/03/09/differences_2026-03-09.xlsx' },
          { date: Date.new(2026, 3, 19), key: latest_key },
        ],
        fetched_bodies: { latest_key => latest_body },
        mailer:,
      )

      service.call

      expect(mailer).to have_received(:differences).exactly(2).times
      expect(emailed_reports.map(&:as_of)).to eq(%w[2026-02-23 2026-03-02])
    end

    it 'uploads but skips email when a nearby off-day rerun exists' do
      latest_key = 'uk/reporting/2026/03/19/differences_2026-03-19.xlsx'
      message = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
      mailer = class_double(ReportsMailer, differences: message)
      existing_reports = [
        { date: Date.new(2026, 2, 23), key: 'uk/reporting/2026/02/23/differences_2026-02-23.xlsx' },
        { date: Date.new(2026, 3, 2), key: 'uk/reporting/2026/03/02/differences_2026-03-02.xlsx' },
        { date: Date.new(2026, 3, 9), key: 'uk/reporting/2026/03/09/differences_2026-03-09.xlsx' },
        { date: Date.new(2026, 3, 17), key: 'uk/reporting/2026/03/17/differences_2026-03-17.xlsx' },
        { date: Date.new(2026, 3, 19), key: latest_key },
      ]
      service = build_service(
        today: Date.new(2026, 3, 20),
        existing_reports:,
        fetched_bodies: {
          latest_key => 'latest-xlsx-data',
          'uk/reporting/2026/03/17/differences_2026-03-17.xlsx' => 'rerun-body',
        },
        mailer:,
      )

      summary = service.call

      expect(mailer).not_to have_received(:differences)
      expect(summary[:email_skipped]).to eq([Date.new(2026, 3, 16)])
    end

    it 'uploads but does not send email when NOEMAIL behaviour is requested' do
      latest_key = 'uk/reporting/2026/03/19/differences_2026-03-19.xlsx'
      mailer = class_double(ReportsMailer, differences: instance_double(ActionMailer::MessageDelivery, deliver_now: true))
      service = build_service(
        today: Date.new(2026, 3, 20),
        existing_reports: base_existing_reports(latest_date: Date.new(2026, 3, 19), latest_key:).reject { |report| report[:date] == Date.new(2026, 2, 23) },
        fetched_bodies: { latest_key => 'latest-xlsx-data' },
        send_email: false,
        mailer:,
      )

      summary = service.call

      expect(mailer).not_to have_received(:differences)
      expect(summary[:emailed]).to eq([])
    end

    it 'reports planned actions without uploading or emailing in dry run mode' do
      latest_key = 'uk/reporting/2026/03/19/differences_2026-03-19.xlsx'
      bucket = instance_double(Aws::S3::Bucket)
      allow(bucket).to receive(:object)
      mailer = class_double(ReportsMailer, differences: instance_double(ActionMailer::MessageDelivery, deliver_now: true))
      service = build_service(
        today: Date.new(2026, 3, 20),
        existing_reports: base_existing_reports(latest_date: Date.new(2026, 3, 19), latest_key:).reject { |report| report[:date] == Date.new(2026, 2, 23) },
        fetched_bodies: { latest_key => 'latest-xlsx-data' },
        dry_run: true,
        mailer:,
        bucket:,
      )

      summary = service.call

      expect(bucket).not_to have_received(:object)
      expect(mailer).not_to have_received(:differences)
      expect(summary[:planned_uploads]).to eq([Date.new(2026, 2, 23)])
      expect(summary[:planned_emails]).to eq([Date.new(2026, 2, 23)])
    end

    it 'does not plan a backfill for the current Monday' do
      latest_key = 'uk/reporting/2026/03/19/differences_2026-03-19.xlsx'
      service = build_service(
        today: Date.new(2026, 3, 23),
        existing_reports: [
          { date: Date.new(2026, 3, 9), key: 'uk/reporting/2026/03/09/differences_2026-03-09.xlsx' },
          { date: Date.new(2026, 3, 19), key: latest_key },
        ],
        fetched_bodies: { latest_key => 'latest-xlsx-data' },
        dry_run: true,
      )

      summary = service.call

      expect(summary[:planned_uploads]).not_to include(Date.new(2026, 3, 23))
    end
  end
end
