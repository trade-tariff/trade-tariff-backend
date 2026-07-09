RSpec.describe Api::User::CommodityChangesSerializer do
  let(:first_tariff_change) { build(:tariff_change, id: 1) }
  let(:second_tariff_change) { build(:tariff_change, id: 2) }
  let(:object) do
    TariffChanges::GroupedCommodityChange.new(
      id: 'ending',
      description: 'desc',
      count: 2,
      tariff_changes: [first_tariff_change, second_tariff_change],
    )
  end
  let(:serializer) { described_class.new([object]) }

  it 'serializes the object and its tariff_changes correctly' do
    result = serializer.serializable_hash
    data = result[:data].first
    expect(data[:id]).to eq('ending')
    expect(data[:type]).to eq(:commodity_changes)
    expect(data[:attributes]).to include(description: 'desc', count: 2)
    expect(data[:relationships][:tariff_changes][:data].map { |rel| rel[:id].to_i }).to contain_exactly(1, 2)
  end
end
