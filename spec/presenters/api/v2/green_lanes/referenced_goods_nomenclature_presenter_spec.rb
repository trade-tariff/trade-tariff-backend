RSpec.describe Api::V2::GreenLanes::ReferencedGoodsNomenclaturePresenter do
  subject(:presenter) { described_class.new(gn) }

  let(:gn) { create :goods_nomenclature, :with_measures }

  it { is_expected.to have_attributes goods_nomenclature_sid: gn.goods_nomenclature_sid }
  it { is_expected.to have_attributes parent_sid: nil }
  it { is_expected.to have_attributes measure_ids: gn.measures.map(&:measure_sid) }

  describe '#measures' do
    subject { presenter.measures }

    it { is_expected.to all be_an Api::V2::GreenLanes::MeasurePresenter }
  end
end
