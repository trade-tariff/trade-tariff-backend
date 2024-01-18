RSpec.describe Api::V2::GreenLanes::GoodsNomenclaturePresenter do
  subject(:presenter) { described_class.new(gn) }

  let(:gn) { create :goods_nomenclature, :with_measures }

  it { is_expected.to have_attributes goods_nomenclature_sid: gn.goods_nomenclature_sid }

  it 'includes applicable measures ids' do
    measure_ids = gn.measures.map(&:id)

    expect(presenter.applicable_measure_ids).to eq measure_ids
  end

  describe '#applicable_measures' do
    subject(:applicable_measures) { presenter.applicable_measures }

    it { is_expected.to all(be_an(Api::V2::Measures::MeasurePresenter)) }

    it { expect(applicable_measures.first.id).to eq(gn.applicable_measures.first.id) }
  end
end
