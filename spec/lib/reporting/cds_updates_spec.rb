RSpec.describe Reporting::CdsUpdates do
  describe '.cds_updates' do
    around do |example|
      travel_to Time.zone.parse('2026-02-15 12:00:00') do
        example.run
      end
    end

    it 'returns only records created in the previous month' do
      january_record = create(
        :cds_update,
        filename: 'tariff_dailyExtract_v1_20260115T000001.gzip',
        created_at: Time.zone.parse('2026-01-15 10:00:00'),
      )
      create(
        :cds_update,
        filename: 'tariff_dailyExtract_v1_20251215T000001.gzip',
        created_at: Time.zone.parse('2025-12-15 10:00:00'),
      )
      create(
        :cds_update,
        filename: 'tariff_dailyExtract_v1_20260201T000001.gzip',
        created_at: Time.zone.parse('2026-02-01 10:00:00'),
      )

      expect(described_class.send(:cds_updates)).to eq([january_record])
    end

    it 'includes records on previous month boundaries only' do
      january_start = create(
        :cds_update,
        filename: 'tariff_dailyExtract_v1_20260101T000001.gzip',
        created_at: Time.zone.parse('2026-01-01 00:00:00'),
      )
      january_end = create(
        :cds_update,
        filename: 'tariff_dailyExtract_v1_20260131T235959.gzip',
        created_at: Time.zone.parse('2026-01-31 23:59:59'),
      )
      create(
        :cds_update,
        filename: 'tariff_dailyExtract_v1_20251231T235959.gzip',
        created_at: Time.zone.parse('2025-12-31 23:59:59'),
      )
      create(
        :cds_update,
        filename: 'tariff_dailyExtract_v1_20260201T000000.gzip',
        created_at: Time.zone.parse('2026-02-01 00:00:00'),
      )

      expect(described_class.send(:cds_updates)).to contain_exactly(january_start, january_end)
    end

    it 'eager-loads state changes' do
      update = create(
        :cds_update,
        filename: 'tariff_dailyExtract_v1_20260115T000001.gzip',
        created_at: Time.zone.parse('2026-01-15 10:00:00'),
      )
      TariffSynchronizer::TariffUpdateStateChange.create(
        tariff_update_filename: update.filename,
        from_state: nil,
        to_state: 'P',
        created_at: Time.zone.parse('2026-01-15 10:00:00'),
      )

      result = described_class.send(:cds_updates)

      expect(result.first.associations).to have_key(:state_changes)
      expect(result.first.state_changes.map(&:to_state)).to eq(%w[P])
    end
  end

  describe '.generate' do
    include_context 'with a stubbed reporting bucket'

    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

      create(
        :cds_update,
        filename: 'tariff_dailyExtract_v1_20260102T000001.gzip',
        issue_date: '2026-01-02',
        created_at: Time.zone.parse('2026-01-02 10:00:00'),
        applied_at: Time.zone.parse('2026-01-02 12:00:00'),
        state: 'A',
      )
      create(
        :cds_update,
        filename: 'tariff_dailyExtract_v1_20260101T000001.gzip',
        issue_date: '2026-01-01',
        created_at: Time.zone.parse('2026-01-01 10:00:00'),
        applied_at: nil,
        state: 'P',
      )
    end

    it 'writes an XLSX file to the reporting bucket' do
      described_class.generate

      expect(s3_bucket.client.api_requests).to include(
        hash_including(
          operation_name: :put_object,
          params: hash_including(
            bucket: s3_bucket.name,
            key: /^.*\/cds_updates_.*\.xlsx$/,
            body: instance_of(String),
            content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ),
      )
    end
  end

  describe '.build_rows_for' do
    it 'returns one row per state transition for the cds update' do
      update = create(
        :cds_update,
        filename: 'tariff_dailyExtract_v1_20260120T000001.gzip',
        issue_date: '2026-01-20',
        created_at: Time.zone.parse('2026-01-20 08:00:00'),
        applied_at: Time.zone.parse('2026-01-20 08:10:00'),
        state: 'A',
      )
      [
        TariffSynchronizer::TariffUpdateStateChange.create(
          tariff_update_filename: update.filename,
          from_state: nil,
          to_state: 'P',
          created_at: Time.zone.parse('2026-01-20 08:00:00'),
        ),
        TariffSynchronizer::TariffUpdateStateChange.create(
          tariff_update_filename: update.filename,
          from_state: 'P',
          to_state: 'A',
          created_at: Time.zone.parse('2026-01-20 08:10:00'),
        ),
      ]

      rows = described_class.send(:build_rows_for, update)

      expect(rows).to eq(
        [
          %w[2026-01-20 2026-01-20T08:00:00Z 2026-01-20T08:00:00Z P],
          %w[2026-01-20 2026-01-20T08:00:00Z 2026-01-20T08:10:00Z A],
        ],
      )
    end

    it 'returns a default row when there are no state transitions' do
      update = create(
        :cds_update,
        filename: 'tariff_dailyExtract_v1_20260122T000001.gzip',
        issue_date: '2026-01-22',
        created_at: Time.zone.parse('2026-01-22 09:00:00'),
        updated_at: Time.zone.parse('2026-01-22 09:05:00'),
        state: 'P',
      )

      rows = described_class.send(:build_rows_for, update)

      expect(rows).to eq(
        [
          %w[2026-01-22 2026-01-22T09:00:00Z 2026-01-22T09:05:00Z P],
        ],
      )
    end
  end
end
