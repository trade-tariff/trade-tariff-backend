RSpec.describe SearchAnalytics::LatencyHistogram do
  def row(bucket, count)
    { 'latency_bucket' => bucket.to_s, 'observations' => count.to_s }
  end

  it 'selects the nearest rank using combined counts, not daily percentile values' do
    first_day = [row(0, 89)]
    second_day = [row(0, 1), row(100, 10)]
    expect(described_class.percentile(first_day + second_day)).to eq(1.05)
    expect(described_class.percentile(second_day)).to be > 100
  end

  it 'moves to the next bucket only when the required rank exceeds the cumulative count' do
    expect(described_class.percentile([row(0, 89), row(1, 11)])).to be_within(0.000001).of(1.1025)
  end

  it 'retains exact zero observations without taking their logarithm' do
    expect(described_class.bucket(0)).to eq(described_class::ZERO_BUCKET)
    expect(described_class.percentile([row(described_class::ZERO_BUCKET, 90), row(1, 10)])).to eq(0)
  end

  it 'returns unavailable for empty or zero-count distributions' do
    expect(described_class.percentile([])).to be_nil
    expect(described_class.percentile([row(1, 0)])).to be_nil
  end

  [0.001, 0.5, 1, 29, 700, 1000, 100_000_000].each do |value|
    it "bounds #{value} milliseconds within five percent" do
      upper = described_class.upper_bound(described_class.bucket(value))
      expect(upper).to be >= value
      expect(upper).to be <= value * 1.05
    end
  end
end
