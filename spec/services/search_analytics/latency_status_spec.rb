RSpec.describe SearchAnalytics::LatencyStatus do
  {
    'classic' => { 0 => 'good', 250 => 'good', 250.001 => 'watch', 500 => 'watch', 525 => 'watch', 525.001 => 'problem', 1000.5 => 'problem' },
    'internal' => { 0 => 'good', 1000.5 => 'good', 25_000 => 'good', 25_000.001 => 'watch', 35_000 => 'watch', 36_750 => 'watch', 36_751 => 'problem' },
  }.each do |view, cases|
    context "with the #{view} view" do
      cases.each do |value, level|
        it "rates an approximate upper bound of #{value} ms as #{level}" do
          expect(described_class.call(value:, view:)).to include('level' => level)
        end
      end
    end
  end

  it 'does not assess the mixed All view against either search type threshold' do
    expect(described_class.call(value: 50_000, view: 'all')).to include('level' => 'neutral', 'message' => /Classic or Internal/)
  end

  it 'keeps missing measurements neutral' do
    expect(described_class.call(value: nil, view: 'classic')).to include('level' => 'neutral', 'message' => /unavailable/)
  end

  { 'classic' => 500, 'internal' => 35_000 }.each do |view, threshold|
    it "does not mark a #{view} histogram bin straddling the problem threshold as red" do
      upper = SearchAnalytics::LatencyHistogram.upper_bound(SearchAnalytics::LatencyHistogram.bucket(threshold))
      expect(described_class.call(value: upper, view:)).to include('level' => 'watch')
    end
  end
end
