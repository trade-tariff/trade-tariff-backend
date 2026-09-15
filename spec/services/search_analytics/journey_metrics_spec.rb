RSpec.describe SearchAnalytics::JourneyMetrics do
  let(:rows) do
    [
      row(%w[first repeat], 'interactive', '2026-09-13T08:00:00Z'),
      row(%w[repeat], 'internal', '2026-09-13T09:00:00Z'),
      row(%w[repeat second], 'interactive', '2026-09-14T08:00:00Z'),
      row(%w[classic], 'classic', '2026-09-14T08:00:00Z'),
      row(%w[other], 'classification', '2026-09-14T08:00:00Z'),
      row(%w[admin], 'interactive', '2026-09-14T08:00:00Z', 'admin'),
      row(%w[mcp], 'interactive', '2026-09-14T08:00:00Z', 'mcp'),
      row(%w[direct], 'interactive', '2026-09-14T08:00:00Z', 'backend_only'),
      row(%w[unknown], 'interactive', '2026-09-14T08:00:00Z', nil),
    ]
  end

  def row(keys, type, time, source = 'frontend')
    { 'journey_keys' => keys, 'search_type' => type, '@timestamp' => time, 'request_source' => source }
  end

  def metrics(view = 'internal', period = '7d', values = rows)
    described_class.new(rows: values, period: SearchAnalytics::Period.for(period:, view:))
  end

  it 'counts each frontend journey once across iterations, subtypes and days' do
    expect(metrics.count).to eq(3)
    expect(metrics.keys.keys).to contain_exactly('first', 'repeat', 'second')
  end

  it 'excludes admin, MCP, direct and missing source markers' do
    expect(metrics('all').keys.keys).to contain_exactly('first', 'repeat', 'second', 'classic', 'other')
  end

  it 'selects Classic separately while All retains other frontend search types' do
    expect(metrics('classic').keys.keys).to eq(%w[classic])
    expect(metrics.all_keys.keys).to contain_exactly('first', 'repeat', 'second', 'classic', 'other')
  end

  it 'deduplicates each chart bucket without summing bucket counts into the headline' do
    expect(metrics.trend).to eq([
      { 'bucket' => '2026-09-13T00:00:00Z', 'all' => 2, 'classic' => 0, 'internal' => 2 },
      { 'bucket' => '2026-09-14T00:00:00Z', 'all' => 4, 'classic' => 1, 'internal' => 2 },
    ])
    expect(metrics.count).to eq(3)
  end

  it 'retains hourly bins for a single day' do
    result = metrics('internal', '24h', rows.first(2))
    expect(result.trend.map { |bucket| bucket['bucket'] }).to eq(%w[2026-09-13T08:00:00Z 2026-09-13T09:00:00Z])
    expect(result.trend.map { |bucket| bucket['internal'] }).to eq([2, 1])
  end

  it 'returns an empty population without inventing journeys' do
    expect(metrics('internal', '24h', []).count).to eq(0)
    expect(metrics('internal', '24h', []).trend).to eq([])
  end
end
