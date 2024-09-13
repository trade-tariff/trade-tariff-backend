RSpec.describe Api::V2::GreenLanes::GoodsNomenclaturePresenter do
  subject(:presenter) { described_class.new(gn) }

  before { category_assessments }

  let(:gn) { create :goods_nomenclature, :with_ancestors, :with_children, :with_measures }

  let :category_assessments do
    create_list :category_assessment, 1, measure: gn.measures.first
  end

  it { is_expected.to have_attributes goods_nomenclature_sid: gn.goods_nomenclature_sid }
  it { is_expected.to have_attributes parent_sid: gn.parent.goods_nomenclature_sid }
  it { is_expected.to have_attributes applicable_category_assessment_ids: presenter.applicable_category_assessments.map(&:id) }
  it { is_expected.to have_attributes ancestor_ids: gn.ancestors.map(&:goods_nomenclature_sid) }

  describe '#applicable_category_assessments' do
    subject { presenter.applicable_category_assessments }

    it { is_expected.to have_attributes length: 1 }
    it { is_expected.to all be_an Api::V2::GreenLanes::CategoryAssessmentPresenter }
    it { is_expected.to all have_attributes id: /^[a-f\d]{32}$/ }
  end

  describe '#applicable_category_assessments' do
    subject { presenter.applicable_category_assessments }

    before {TradeTariffRequest.green_lanes = true}

    let(:gn) { create :goods_nomenclature, :with_ancestors, :with_children, :with_quota_measures }

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

  context 'when filtering by origin' do
    subject(:presented) { described_class.new(gn, geo_area_id) }

    context 'with matching geo area' do
      let(:geo_area_id) { gn.measures.first.geographical_area_id }

      describe '#applicable_category_assessments' do
        subject { presented.applicable_category_assessments }

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
    end

    context 'with blank geo area' do
      let(:geo_area_id) { '   ' }

      it { expect(presented.applicable_category_assessments).to have_attributes length: 1 }
    end
  end

  describe '#descendant_category_assessments' do
    subject { presenter.descendant_category_assessments }

    let(:gn) { create :goods_nomenclature, :with_ancestors, :with_children }
    let(:measures) { [measure, measure2] }

    let :measure do
      create :measure, goods_nomenclature: gn.children.first,
                       generating_regulation: create(:base_regulation)
    end

    let :measure2 do
      create :measure, goods_nomenclature: gn.children.first.children.first,
                       generating_regulation: create(:base_regulation)
    end

    let :category_assessments do
      measures.map { |m| create :category_assessment, measure: m }
    end

    it { is_expected.to have_attributes length: 2 }

    context 'with same assessment on multiple descendants' do
      let :category_assessments do
        create_list :category_assessment, 1, measure: measures.first
      end

      let :measure2 do
        create :measure, goods_nomenclature: gn.children.first.children.first,
                         measure_type_id: measure.measure_type_id,
                         generating_regulation: measure.generating_regulation,
                         geographical_area_id: measure.geographical_area_id
      end

      it { is_expected.to have_attributes length: 1 }
    end

    context 'with non matching geo area' do
      let :category_assessments do
        create_list :category_assessment, 1, measure: measures.first
      end

      let :measure2 do
        create :measure, goods_nomenclature: gn.children.first.children.first,
                         measure_type_id: measure.measure_type_id,
                         generating_regulation: measure.generating_regulation
      end

      it { is_expected.to have_attributes length: 2 }
    end
  end

  describe '#supplementary_measure_unit' do
    subject(:presented) { described_class.new(gn, requested_geo_area) }

    before do
      create :measure,
             :supplementary,
             :with_base_regulation,
             goods_nomenclature: gn.parent,
             for_geo_area: geo_area
    end

    let(:geo_area) { create :geographical_area, geographical_area_id: 'FR' }
    let(:requested_geo_area) { 'FR' }

    context 'with origin filter which matches' do
      it { is_expected.to have_attributes supplementary_measure_unit: /\w+ \(\w+\)/ }
    end

    context 'with origin filter which does not match' do
      let(:requested_geo_area) { 'DE' }

      it { is_expected.to have_attributes supplementary_measure_unit: nil }
    end

    context 'without origin filter' do
      let(:requested_geo_area) { '' }

      it { is_expected.to have_attributes supplementary_measure_unit: nil }
    end

    context 'without origin filter but with Erga Omnes Supplementary Measure' do
      let(:requested_geo_area) { '' }
      let(:geo_area) { create :geographical_area, :erga_omnes }

      it { is_expected.to have_attributes supplementary_measure_unit: /\w+ \(\w+\)/ }
    end

    context 'with certificate against ancestor GN' do
      subject(:presented) { described_class.new(gn.descendants.first, requested_geo_area) }

      it { is_expected.to have_attributes supplementary_measure_unit: /\w+ \(\w+\)/ }
    end

    context 'with export measure' do
      before { MeasureType::Operation.dataset.update trade_movement_code: 1 }

      it { is_expected.to have_attributes supplementary_measure_unit: nil }
    end
  end

  describe '#licences' do
    subject(:presented) { described_class.new(gn.reload, requested_geo_area) }

    before do
      create(:measure,
             :with_base_regulation,
             goods_nomenclature: gn,
             for_geo_area: geo_area).tap do |meas|
        create(:measure_condition, measure: meas, certificate:)
      end
    end

    let(:geo_area) { create :geographical_area, geographical_area_id: 'FR' }
    let(:requested_geo_area) { 'FR' }
    let(:certificate) { create :certificate, :licence }

    context 'with origin filter which matches' do
      it { is_expected.to have_attributes licences: [certificate] }
    end

    context 'with origin filter which does not match' do
      let(:requested_geo_area) { 'DE' }

      it { is_expected.to have_attributes licences: [] }
    end

    context 'without origin filter' do
      let(:requested_geo_area) { '' }

      it { is_expected.to have_attributes licences: [] }
    end

    context 'without origin filter but with Erga Omnes Supplementary Measure' do
      let(:requested_geo_area) { '' }
      let(:geo_area) { create :geographical_area, :erga_omnes }

      it { is_expected.to have_attributes licences: [certificate] }
    end

    context 'with matching origin filter but non licence certificate' do
      let(:certificate) { create :certificate, :exemption }

      it { is_expected.to have_attributes licences: [] }
    end

    context 'with certificate against ancestor GN' do
      subject(:presented) { described_class.new(gn.descendants.first, requested_geo_area) }

      it { is_expected.to have_attributes licences: [certificate] }
    end

    context 'with export measure' do
      before { MeasureType::Operation.dataset.update trade_movement_code: 1 }

      it { is_expected.to have_attributes licences: [] }
    end
  end
end
