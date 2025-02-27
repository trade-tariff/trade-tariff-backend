RSpec.describe Subheading do
  before do
    TradeTariffRequest.time_machine_now = Time.current
  end

  describe '#to_param' do
    subject(:to_param) { described_class.find(goods_nomenclature_item_id: '0101210000', producline_suffix: '10').to_param }

    before { create(:commodity, producline_suffix: '10', goods_nomenclature_item_id: '0101210000') }

    it { is_expected.to eq('0101210000-10') }
  end

  describe '#short_code' do
    context 'when the subheading is a harmonised system code' do
      subject(:short_code) { described_class.find(goods_nomenclature_item_id: '0101210000', producline_suffix: '10').short_code }

      before { create(:commodity, producline_suffix: '10', goods_nomenclature_item_id: '0101210000') }

      it { is_expected.to eq('010121') }
    end

    context 'when the subheading is a combined nomenclature code' do
      subject(:short_code) { described_class.find(goods_nomenclature_item_id: '0101210900', producline_suffix: '10').short_code }

      before { create(:commodity, producline_suffix: '10', goods_nomenclature_item_id: '0101210900') }

      it { is_expected.to eq('01012109') }
    end

    context 'when the subheading is a taric code' do
      subject(:short_code) { described_class.find(goods_nomenclature_item_id: '0101210900', producline_suffix: '80').short_code }

      before { create(:commodity, producline_suffix: '80', goods_nomenclature_item_id: '0101210900') }

      it { is_expected.to eq('0101210900') }
    end
  end

  describe '#goods_nomenclature_class' do
    subject do
      described_class.find(goods_nomenclature_item_id: '0101210000', producline_suffix: '10')
                     .goods_nomenclature_class
    end

    before { create(:commodity, producline_suffix: '10', goods_nomenclature_item_id: '0101210000') }

    it { is_expected.to eq('Subheading') }
  end
end
