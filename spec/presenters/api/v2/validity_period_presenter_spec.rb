RSpec.describe Api::V2::ValidityPeriodPresenter do
  describe '#id' do
    subject(:id) { described_class.new(goods_nomenclature).id }

    context 'with commodity' do
      let(:goods_nomenclature) { build(:commodity) }

      it { is_expected.to be_present }
    end

    context 'with heading' do
      let(:goods_nomenclature) { build(:heading) }

      it { is_expected.to be_present }
    end

    context 'with subheading' do
      let(:goods_nomenclature) { build(:subheading) }

      it { is_expected.to be_present }
    end
  end
end
