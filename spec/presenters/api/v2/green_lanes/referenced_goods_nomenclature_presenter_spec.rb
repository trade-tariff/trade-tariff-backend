RSpec.describe Api::V2::GreenLanes::ReferencedGoodsNomenclaturePresenter do
  subject(:presenter) { described_class.new(gn, geo_area_id) }

  let(:gn) { create :goods_nomenclature, :with_measures }
  let(:geo_area_id) { nil }

  it { is_expected.to have_attributes goods_nomenclature_sid: gn.goods_nomenclature_sid }
  it { is_expected.to have_attributes parent_sid: nil }
  it { is_expected.to have_attributes measure_ids: gn.measures.map(&:measure_sid) }

  describe '#measures' do
    subject { presenter.measures }

    it { is_expected.to all be_an Api::V2::GreenLanes::MeasurePresenter }

    context 'when filtering by origin' do
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
  end

  describe '#supplementary_measure_unit' do
    subject(:presented) { described_class.new(gn, requested_geo_area) }

    before do
      create :measure,
             :supplementary,
             :with_base_regulation,
             goods_nomenclature: gn,
             for_geo_area: geo_area
    end

    let(:geo_area) { create :geographical_area, geographical_area_id: 'FR' }

    context 'with origin filter which does match' do
      let(:requested_geo_area) { 'FR' }

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
  end
end
