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

  describe '#deriving_goods_nomenclatures' do
    subject(:deriving_goods_nomenclatures) { described_class.new(goods_nomenclature).deriving_goods_nomenclatures }

    context 'when the goods nomenclature has a validity start date before the Brexit starting date' do
      let(:goods_nomenclature) { build(:commodity, validity_start_date: Date.new(2020, 1, 1)) }

      it { is_expected.to be_empty }
    end

    context 'when the goods nomenclature has a validity start date after the Brexit starting date' do
      let(:goods_nomenclature) { build(:commodity, validity_start_date: Date.new(2021, 1, 2)) }

      it { is_expected.to all(be_a(Commodity)) }
    end

    context 'when the goods nomenclature has a validity start date equal to the Brexit starting date' do
      let(:goods_nomenclature) { build(:commodity, validity_start_date: Date.new(2021, 1, 1)) }

      it { is_expected.to all(be_a(Commodity)) }
    end
  end

  describe '.wrap' do
    subject(:wrap) { described_class.wrap(goods_nomenclatures) }

    context 'when the goods nomenclature is a collection' do
      let(:goods_nomenclatures) { build_list(:commodity, 2) }

      it { is_expected.to all(be_a(described_class)) }
    end

    context 'when the goods nomenclature is a single goods nomenclature' do
      let(:goods_nomenclatures) { build(:commodity) }

      it { is_expected.to all(be_a(described_class)) }
    end
  end
end
