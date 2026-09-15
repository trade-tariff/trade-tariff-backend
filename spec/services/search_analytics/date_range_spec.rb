RSpec.describe SearchAnalytics::DateRange do
  let(:now) { Time.utc(2026, 9, 15, 0, 30) }

  it 'includes both endpoints' do
    range = described_class.parse(from: '2026-09-01', to: '2026-09-07', now:)
    expect(range.days).to eq(7)
    expect(range.dates).to eq((Date.new(2026, 9, 1)..Date.new(2026, 9, 7)).to_a)
  end

  it 'supports a single historical date' do
    range = described_class.parse(from: '2026-09-01', to: '2026-09-01', now:)
    period = SearchAnalytics::Period.for_range(date_range: range, view: 'classic')
    expect(period).to have_attributes(key: 'custom', view: 'classic', duration: 1.day, bucket_size: 'hour')
    expect(period).to be_single_day
  end

  it 'accepts exactly 366 days' do
    expect(described_class.parse(from: '2025-09-14', to: '2026-09-14', now:).days).to eq(366)
  end

  it 'handles leap days as calendar days' do
    expect(described_class.parse(from: '2024-02-28', to: '2024-03-01', now:).days).to eq(3)
  end

  [
    [nil, '2026-09-14'],
    ['2026-09-14', nil],
    ['', ''],
    ['14/09/2026', '2026-09-14'],
    ['2026-09-31', '2026-09-14'],
    ['2026-09-14', '2026-09-13'],
    ['2026-09-14', '2026-09-15'],
    ['2025-09-13', '2026-09-14'],
    [%w[2026-09-14], '2026-09-14'],
    ['0000-01-01', '0000-01-01'],
  ].each do |from, to|
    it "rejects invalid dates #{from.inspect} to #{to.inspect}" do
      expect { described_class.parse(from:, to:, now:) }.to raise_error(described_class::InvalidRange)
    end
  end
end
