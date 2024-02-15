RSpec.describe Api::V2::GreenLanes::GoodsNomenclaturePresenter do
  subject(:presenter) { described_class.new(gn, [presented_category_assessment]) }

  let(:gn) { create :goods_nomenclature, :with_measures }
  let(:first_measure) { gn.measures.first }

  let :presented_category_assessment do
    ::Api::V2::GreenLanes::CategoryAssessmentPresenter.new category_assessment, [first_measure]
  end

  let(:category_assessment) do
    build :category_assessment, measure: first_measure,
                                geographical_area_id: '1000'
  end

  it { is_expected.to have_attributes goods_nomenclature_sid: gn.goods_nomenclature_sid }

  it 'includes applicable measures ids' do
    expect(presenter.applicable_measure_ids).to eq gn.applicable_measures.map(&:id)
  end

  it 'includes applicable category assessment ids' do
    expect(presenter.applicable_category_assessment_ids).to eq [category_assessment.id]
  end

  describe '#applicable_measures' do
    subject(:applicable_measures) { presenter.applicable_measures }

    it { is_expected.to all(be_an(Api::V2::Measures::MeasurePresenter)) }

    it { expect(applicable_measures.first.id).to eq(gn.applicable_measures.first.id) }
  end

  describe '#applicable_category_assessments' do
    subject(:applicable_category_assessments) { presenter.applicable_category_assessments }

    it { is_expected.to all(be_an(Api::V2::GreenLanes::CategoryAssessmentPresenter)) }

    it { expect(applicable_category_assessments.first.id).to eq(category_assessment.id) }
  end
end
