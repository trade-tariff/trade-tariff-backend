RSpec.describe TariffChanges::GroupedCommodityChange do
  subject(:grouped_change) do
    described_class.new(
      id: 'ending',
      description: 'desc',
      count: 2,
      tariff_changes: [create(:tariff_change, id: 1), create(:tariff_change, id: 2)],
    )
  end

  it 'has the correct attributes' do
    expect(grouped_change.id).to eq('ending')
    expect(grouped_change.description).to eq('desc')
    expect(grouped_change.count).to eq(2)
    expect(grouped_change.tariff_changes.size).to eq(2)
  end

  describe '#tariff_change_ids' do
    it 'returns the ids of the tariff_changes' do
      expect(grouped_change.tariff_change_ids).to eq([1, 2])
    end
  end

  it 'defaults tariff_changes to an empty array if not provided' do
    change = described_class.new(id: 'ending', description: 'desc', count: 0)
    expect(change.tariff_changes).to eq([])
    expect(change.tariff_change_ids).to eq([])
  end
end
