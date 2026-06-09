RSpec.describe Api::User::TariffChangeSerializer do
  let(:goods_nomenclature) { create(:goods_nomenclature) }
  let(:tariff_change) do
    create(
      :tariff_change,
      date_of_effect: Date.new(2025, 10, 17),
      goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
    )
  end

  it 'serializes the basic attributes' do
    result = described_class.new([tariff_change]).serializable_hash
    data = result[:data].first
    expect(data[:id]).to eq tariff_change.id.to_s
    expect(data[:type]).to eq(:tariff_change)
    expect(data[:attributes]).to include(
      description: tariff_change.description,
      date_of_effect: '17/10/2025',
      goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
    )
  end

  it 'serializes the classification_description' do
    allow(tariff_change).to receive(:goods_nomenclature).and_return(goods_nomenclature)
    allow(goods_nomenclature).to receive(:classification_description).and_return('Test Classification Description')
    allow(TimeMachine).to receive(:at).and_yield
    result = described_class.new([tariff_change]).serializable_hash
    data = result[:data].first
    expect(data[:attributes][:classification_description]).to eq('Test Classification Description')
  end

  it 'serializes date_of_effect as end date removed when end date is removed' do
    removed_end_date_change = create(
      :tariff_change,
      action: TariffChangesService::BaseChanges::ENDING,
      validity_end_date: nil,
      date_of_effect: Date.new(2025, 10, 17),
      goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
    )

    result = described_class.new([removed_end_date_change]).serializable_hash
    data = result[:data].first

    expect(data[:attributes][:date_of_effect]).to eq(TariffChange::END_DATE_REMOVED_DISPLAY)
  end
end
