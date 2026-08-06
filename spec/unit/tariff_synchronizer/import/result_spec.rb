RSpec.describe TariffSynchronizer::Import::Result do
  subject(:result) do
    described_class.new(
      operations: { create: { count: 1, duration: 0.5 } },
      total_count: 1,
      total_duration: 0.5,
    )
  end

  it 'is a Hash' do
    expect(result).to be_a(Hash)
  end

  it 'exposes operations, total_count and total_duration via bracket access' do
    expect(result[:operations]).to eq(create: { count: 1, duration: 0.5 })
    expect(result[:total_count]).to eq(1)
    expect(result[:total_duration]).to eq(0.5)
  end

  it 'supports #fetch with a default like a plain hash' do
    expect(result.fetch(:total_count, 0)).to eq(1)
    expect(result.fetch(:missing_key, 0)).to eq(0)
  end

  it 'serializes to JSON as a plain hash' do
    parsed = JSON.parse(result.to_json)

    expect(parsed).to eq(
      'operations' => { 'create' => { 'count' => 1, 'duration' => 0.5 } },
      'total_count' => 1,
      'total_duration' => 0.5,
    )
  end
end
