RSpec.describe Api::V2::GreenLanes::GoodsNomenclaturePresenter do
  subject(:presenter) { described_class.new(gn, [presented_assessment]) }

  let(:gn) { create :goods_nomenclature, :with_measures }
  let(:assessment) { create :category_assessment, measure: gn.measures.first }

  let :permutations do
    GreenLanes::PermutationCalculatorService.new(gn.applicable_measures).call
  end

  let :presented_assessment do
    Api::V2::GreenLanes::CategoryAssessmentPresenter.new(assessment, *permutations.first)
  end

  it { is_expected.to have_attributes goods_nomenclature_sid: gn.goods_nomenclature_sid }
  it { is_expected.to have_attributes applicable_category_assessment_ids: [presented_assessment.id] }

  describe '#applicable_category_assessments' do
    subject { presenter.applicable_category_assessments }

    it { is_expected.to have_attributes length: 1 }
    it { is_expected.to all be_an Api::V2::GreenLanes::CategoryAssessmentPresenter }
    it { is_expected.to all have_attributes id: presented_assessment.id }
  end
end
