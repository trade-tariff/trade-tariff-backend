RSpec.describe GoodsNomenclatureResult do
  subject(:result) do
    described_class.new(
      id: 12_345,
      goods_nomenclature_item_id: '0101210000',
      goods_nomenclature_sid: 12_345,
      producline_suffix: '80',
      goods_nomenclature_class: 'Commodity',
      description: 'Live horses',
      formatted_description: 'Live horses',
      self_text: nil,
      classification_description: 'Live horses',
      full_description: 'Live horses',
      heading_description: 'Live horses and asses',
      declarable: true,
      score: 0.95,
      confidence: nil,
    )
  end

  it { is_expected.to be_a Data }

  it 'exposes all fields' do
    expect(result.id).to eq(12_345)
    expect(result.goods_nomenclature_item_id).to eq('0101210000')
    expect(result.goods_nomenclature_sid).to eq(12_345)
    expect(result.producline_suffix).to eq('80')
    expect(result.goods_nomenclature_class).to eq('Commodity')
    expect(result.description).to eq('Live horses')
    expect(result.formatted_description).to eq('Live horses')
    expect(result.self_text).to be_nil
    expect(result.classification_description).to eq('Live horses')
    expect(result.full_description).to eq('Live horses')
    expect(result.heading_description).to eq('Live horses and asses')
    expect(result.declarable).to be true
    expect(result.score).to eq(0.95)
    expect(result.confidence).to be_nil
  end

  it 'is frozen/immutable' do
    expect(result).to be_frozen
  end

  it 'supports equality by value' do
    other = described_class.new(
      id: 12_345,
      goods_nomenclature_item_id: '0101210000',
      goods_nomenclature_sid: 12_345,
      producline_suffix: '80',
      goods_nomenclature_class: 'Commodity',
      description: 'Live horses',
      formatted_description: 'Live horses',
      self_text: nil,
      classification_description: 'Live horses',
      full_description: 'Live horses',
      heading_description: 'Live horses and asses',
      declarable: true,
      score: 0.95,
      confidence: nil,
    )

    expect(result).to eq(other)
  end
end
