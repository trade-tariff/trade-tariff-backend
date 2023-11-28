RSpec.describe Api::V2::GreenLanes::SubheadingPresenter do
  subject(:presenter) { described_class.new subheading }

  let(:subheading) { create :subheading, :with_measures }

  it { is_expected.to have_attributes goods_nomenclature_sid: subheading.goods_nomenclature_sid }

  it 'includes applicable measures ids' do
    expect(presenter.applicable_measure_ids).to eq subheading.applicable_measures.map(&:id)
  end

  describe '#applicable_measures' do
    subject(:applicable_measures) { presenter.applicable_measures }

    it { is_expected.to all(be_an(Api::V2::Measures::MeasurePresenter)) }

    it { expect(applicable_measures.first.id).to eq(subheading.applicable_measures.first.id) }
  end
end
