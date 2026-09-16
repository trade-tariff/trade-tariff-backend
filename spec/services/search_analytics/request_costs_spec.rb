RSpec.describe SearchAnalytics::RequestCosts do
  let(:keys) { { 'journey' => true, 'free-lookup' => true } }
  let(:trend_rows) do
    [
      call_row('journey', '0.004', 'embedding'),
      call_row('journey', '0.006', 'question'),
      call_row('journey', '0.02', 'answer'),
      call_row('admin', '1.00', 'question'),
      call_row('unlinked', '2.00', 'question'),
    ]
  end

  def call_row(key, cost, kind, priced = 1, unpriced = 0)
    { 'journey_key' => key,
      'total_cost_usd' => cost,
      'event_kind' => kind,
      'calls' => (priced + unpriced).to_s,
      'priced_calls' => priced.to_s,
      'unpriced_calls' => unpriced.to_s }
  end

  def result
    described_class.new(trend_rows:, journey_keys: keys).call
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

  it 'derives totals from exactly the same rows as the operation trend after replacement' do
    trend_rows.replace([call_row('journey', '0.04', 'answer', 2, 1)])
    expect(result[:summary]).to include('total_cost_usd' => '0.04', 'priced_calls' => 2, 'unpriced_calls' => 1)
    expect(result[:trend]).to eq(trend_rows)
  end
end
