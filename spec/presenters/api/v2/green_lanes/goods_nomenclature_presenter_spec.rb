RSpec.describe Api::V2::GreenLanes::GoodsNomenclaturePresenter do
  subject(:presenter) { described_class.new(gn) }

  before { create :category_assessment, measure: gn.measures.first }

  let(:gn) { create :goods_nomenclature, :with_parent, :with_measures }

  it { is_expected.to have_attributes goods_nomenclature_sid: gn.goods_nomenclature_sid }
  it { is_expected.to have_attributes applicable_category_assessment_ids: presenter.applicable_category_assessments.map(&:id) }
  it { is_expected.to have_attributes ancestor_ids: [gn.parent.goods_nomenclature_sid] }
  it { is_expected.to have_attributes measure_ids: [gn.measures.first.measure_sid] }

  describe '#applicable_category_assessments' do
    subject { presenter.applicable_category_assessments }

    it { is_expected.to have_attributes length: 1 }
    it { is_expected.to all be_an Api::V2::GreenLanes::CategoryAssessmentPresenter }
    it { is_expected.to all have_attributes id: /^[a-f\d]{32}$/ }
  end

  context 'when filtering by origin' do
    subject do
      described_class.new(gn, geo_area_id).applicable_category_assessments
    end

    context 'with matching geo area' do
      let(:geo_area_id) { gn.measures.first.geographical_area_id }

      it { is_expected.to have_attributes length: 1 }
      it { is_expected.to all have_attributes geographical_area_id: /\w+/ }
    end

    context 'with non matching geo area' do
      before { create :geographical_area, geographical_area_id: 'IR' }

      let(:geo_area_id) { 'IR' }

      it { is_expected.to be_empty }
    end

    context 'with blank geo area' do
      let(:geo_area_id) { '   ' }

      it { is_expected.to have_attributes length: 1 }
    end
  end

  describe '#ancestors' do
    subject { presenter.ancestors }

    it { is_expected.to have_attributes length: 1 }
    it { is_expected.to all be_an Api::V2::GreenLanes::ReferencedGoodsNomenclaturePresenter }
  end

  describe '#measures' do
    subject { presenter.measures }

    it { is_expected.to have_attributes length: 1 }
    it { is_expected.to all be_an Api::V2::GreenLanes::MeasurePresenter }
  end
end
