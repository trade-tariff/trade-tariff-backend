RSpec.describe SearchAnalytics::RequestCosts do
  let(:keys) { { 'journey' => true, 'free-lookup' => true } }
  let(:summary_rows) do
    [
      summary('journey', '0.01', 2),
      summary('journey', '0.02', 1),
      summary('admin', '1.00', 1),
      summary('unlinked', '2.00', 1),
    ]
  end
  let(:trend_rows) do
    [
      call_row('journey', '0.004', 'embedding'),
      call_row('journey', '0.006', 'question'),
      call_row('journey', '0.02', 'answer'),
      call_row('admin', '1.00', 'question'),
      call_row('unlinked', '2.00', 'question'),
    ]
  end

  def summary(key, cost, priced = 1, unpriced = 0)
    { 'journey_key' => key, 'total_cost_usd' => cost, 'priced_calls' => priced.to_s, 'unpriced_calls' => unpriced.to_s }
  end

  def call_row(key, cost, kind, priced = 1, unpriced = 0)
    summary(key, cost, priced, unpriced).merge('event_kind' => kind, 'calls' => (priced + unpriced).to_s)
  end

  def result
    described_class.new(summary_rows:, trend_rows:, journey_keys: keys).call
  end

  it 'sums every call for selected IDs without requiring source metadata on call events' do
    expect(result[:summary]).to include('total_cost_usd' => '0.03', 'priced_calls' => 3, 'assisted_searches' => 1)
    expect(result[:trend].map { |row| row['event_kind'] }).to eq(%w[embedding question answer])
  end

  it 'does not count a selected no-AI lookup as an assisted journey' do
    expect(keys.size).to eq(2)
    expect(result[:summary]['assisted_searches']).to eq(1)
  end

  it 'retains failed calls and reports missing costs separately from known costs' do
    summary_rows << summary('journey', '0', 0, 1)
    trend_rows << call_row('journey', '0', 'question', 0, 1).merge('response_type' => 'error')

    expect(result[:summary]).to include('total_cost_usd' => '0.03', 'priced_calls' => 3, 'unpriced_calls' => 1)
    expect(result[:trend].last['response_type']).to eq('error')
  end

  it 'keeps recorded costs of a failed response' do
    trend_rows.first['response_type'] = 'error'
    expect(result[:summary]['total_cost_usd']).to eq('0.03')
  end

  it 'does not retain admin or unlinked costs outside the selected IDs' do
    expect(result[:trend].map { |row| row['journey_key'] }.uniq).to eq(%w[journey])
  end

  it 'returns zero calls and cost when no journey IDs are selected' do
    keys.clear
    expect(result[:summary]).to include('total_cost_usd' => '0.0', 'priced_calls' => 0, 'assisted_searches' => 0)
    expect(result[:trend]).to eq([])
  end

  it 'rejects a trend containing an ID absent from the summary' do
    trend_rows << call_row('missing', '0.01', 'question')
    expect { result }.to raise_error(ArgumentError, /request identifiers/)
  end

  %w[priced_calls unpriced_calls].each do |field|
    it "rejects disagreement in #{field}" do
      summary_rows.first[field] = '99'
      expect { result }.to raise_error(ArgumentError, /#{field}/)
    end
  end

  it 'rejects mismatched costs without silently publishing a partial total' do
    summary_rows.first['total_cost_usd'] = '0.011'
    expect { result }.to raise_error(ArgumentError, /recorded costs/)
  end

  it 'allows insignificant floating-point serialization differences' do
    summary_rows.first['total_cost_usd'] = '0.010000000000000001'
    expect(result[:summary]['total_cost_usd']).to eq('0.030000000000000001')
  end
end
