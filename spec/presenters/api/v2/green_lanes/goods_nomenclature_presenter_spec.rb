RSpec.describe Api::V2::GreenLanes::GoodsNomenclaturePresenter do
  subject(:presenter) { described_class.new(gn) }

  before { create :category_assessment, measure: gn.measures.first }

  let(:gn) { create :goods_nomenclature, :with_ancestors, :with_children, :with_measures }

  it { is_expected.to have_attributes goods_nomenclature_sid: gn.goods_nomenclature_sid }
  it { is_expected.to have_attributes parent_sid: gn.parent.goods_nomenclature_sid }
  it { is_expected.to have_attributes applicable_category_assessment_ids: presenter.applicable_category_assessments.map(&:id) }
  it { is_expected.to have_attributes ancestor_ids: gn.ancestors.map(&:goods_nomenclature_sid) }
  it { is_expected.to have_attributes measure_ids: [gn.measures.first.measure_sid] }

  describe '#applicable_category_assessments' do
    subject { presenter.applicable_category_assessments }

    it { is_expected.to have_attributes length: 1 }
    it { is_expected.to all be_an Api::V2::GreenLanes::CategoryAssessmentPresenter }
    it { is_expected.to all have_attributes id: /^[a-f\d]{32}$/ }
  end

  describe '#ancestors' do
    subject { presenter.ancestors }

    it { is_expected.to have_attributes length: 2 }
    it { is_expected.to all be_an Api::V2::GreenLanes::ReferencedGoodsNomenclaturePresenter }
  end

  describe '#descendants' do
    subject { presenter.descendants }

    it { is_expected.to have_attributes length: 2 }
    it { is_expected.to all be_an Api::V2::GreenLanes::ReferencedGoodsNomenclaturePresenter }
  end

  describe '#measures' do
    subject { presenter.measures }

    it { is_expected.to have_attributes length: 1 }
    it { is_expected.to all be_an Api::V2::GreenLanes::MeasurePresenter }
  end

  context 'when filtering by origin' do
    subject(:presented) { described_class.new(gn, geo_area_id) }

    context 'with matching geo area' do
      let(:geo_area_id) { gn.measures.first.geographical_area_id }

      describe '#applicable_category_assessments' do
        subject { presented.applicable_category_assessments }

        it { is_expected.to have_attributes length: 1 }
        it { is_expected.to all have_attributes geographical_area_id: /\w+/ }
      end

      describe '#measures' do
        subject { presented.measures }

        it { is_expected.to have_attributes length: 1 }
        it { is_expected.to all have_attributes geographical_area_id: /\w+/ }
      end

      describe '#ancestors' do
        subject(:ancestors) { presented.ancestors }

        before do
          allow(Api::V2::GreenLanes::ReferencedGoodsNomenclaturePresenter).to \
            receive(:wrap).and_call_original
        end

        it 'passes geo area to ancestors presenter' do
          ancestors

          expect(Api::V2::GreenLanes::ReferencedGoodsNomenclaturePresenter).to \
            have_received(:wrap).with(gn.ancestors, geo_area_id)
        end
      end

      describe '#descendants' do
        subject(:descendants) { presented.descendants }

        before do
          allow(Api::V2::GreenLanes::ReferencedGoodsNomenclaturePresenter).to \
            receive(:wrap).and_call_original
        end

        it 'passes geo area to ancestors presenter' do
          descendants

          expect(Api::V2::GreenLanes::ReferencedGoodsNomenclaturePresenter).to \
            have_received(:wrap).with(gn.descendants, geo_area_id)
        end
      end
    end

    context 'with non matching geo area' do
      before { create :geographical_area, geographical_area_id: 'IR' }

      let(:geo_area_id) { 'IR' }

      it { is_expected.to have_attributes applicable_category_assessments: be_empty }
      it { is_expected.to have_attributes measures: be_empty }
    end

    context 'with blank geo area' do
      let(:geo_area_id) { '   ' }

      it { expect(presented.applicable_category_assessments).to have_attributes length: 1 }
      it { expect(presented.measures).to have_attributes length: 1 }
    end
  end
end
