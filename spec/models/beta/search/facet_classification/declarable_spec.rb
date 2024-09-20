RSpec.describe Beta::Search::FacetClassification::Declarable do
  before do
    TradeTariffRequest.time_machine_now = Time.current
  end

  describe '.build' do
    subject(:result) { described_class.build(goods_nomenclature) }

    let(:goods_nomenclature) do
      commodity = create(:commodity, :with_ancestors)

      GoodsNomenclature.find(goods_nomenclature_sid: commodity.goods_nomenclature_sid)
    end

    let(:expected_classifications) do
      {
        'animal_product_state' => 'live',
        'animal_type' => 'equine animals',
      }
    end

    it { is_expected.to be_a(Beta::Search::FacetClassification) }
    it { expect(result.classifications).to eq(expected_classifications) }
  end
end
