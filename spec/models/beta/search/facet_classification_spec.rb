require 'rails_helper'

RSpec.describe Beta::Search::FacetClassification do
  describe '.build' do
    subject(:result) { described_class.build(goods_nomenclature) }

    let(:goods_nomenclature) do
      commodity = create(:commodity, :with_ancestors)

      GoodsNomenclature.find(goods_nomenclature_sid: commodity.goods_nomenclature_sid)
    end

    let(:expected_classifications) do
      {
        'animal_product_state' => Set.new(%w[live]),
        'animal_type' => Set.new(['equine animals']),
      }
    end

    it { is_expected.to be_a(described_class) }
    it { expect(result.classifications).to eq(expected_classifications) }
  end

  describe '.empty' do
    subject(:empty) { described_class.empty }

    it { is_expected.to be_a(described_class) }
    it { expect(empty.classifications).to eq({}) }
  end
end
