RSpec.describe SearchDiagnostics::TimeWindow do
  let(:now) { Time.zone.parse('2026-06-05 10:00:00 UTC') }

  describe '.resolve' do
    it 'defaults to the last 72 hours' do
      window = described_class.resolve(now:)

      expect(window).to have_attributes(start_time: now - 72.hours, end_time: now)
    end

    it 'allows a two-week lookback' do
      window = described_class.resolve(lookback_hours: '336', now:)

      expect(window.start_time).to eq(now - 14.days)
    end

    it 'clamps longer lookbacks to two weeks' do
      window = described_class.resolve(lookback_hours: '9999', now:)

      expect(window.start_time).to eq(now - 14.days)
    end

    it 'covers whole UTC days for a date range' do
      window = described_class.resolve(from: '2026-05-01', to: '2026-05-02', now:)

      expect(window).to have_attributes(
        start_time: Time.utc(2026, 5, 1),
        end_time: Time.utc(2026, 5, 2).end_of_day,
      )
    end

    it 'stops a range ending today at the current time' do
      window = described_class.resolve(from: '2026-06-05', to: '2026-06-05', now:)

      expect(window.end_time).to eq(now)
    end

    it 'prefers a date range over a lookback' do
      window = described_class.resolve(lookback_hours: '24', from: '2026-06-01', to: '2026-06-01', now:)

      expect(window.start_time).to eq(Time.utc(2026, 6, 1))
    end

    {
      { from: '2026-06-01', to: nil } => 'Enter both From and To dates in YYYY-MM-DD format.',
      { from: '2026-02-30', to: '2026-03-01' } => 'Enter valid calendar dates for From and To.',
      { from: '2026-06-02', to: '2026-06-01' } => 'From must be on or before To.',
      { from: '2026-06-05', to: '2026-06-06' } => 'To must be today or earlier (UTC).',
      { from: '2026-03-06', to: '2026-03-07' } => 'From must be within the last 90 days.',
      { from: '2026-04-01', to: '2026-05-02' } => 'Choose a range of no more than 31 days.',
    }.each do |dates, message|
      it "rejects #{dates.inspect}" do
        expect { described_class.resolve(**dates, now:) }
          .to raise_error(described_class::InvalidWindow, message)
      end
    end
  end
end
