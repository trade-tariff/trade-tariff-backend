RSpec.describe Api::V2::GreenLanes::ReferencedGoodsNomenclaturePresenter do
  subject(:presenter) { described_class.new(gn, geo_area_id) }

  let(:gn) { create :goods_nomenclature, :with_measures }
  let(:geo_area_id) { nil }

  it { is_expected.to have_attributes goods_nomenclature_sid: gn.goods_nomenclature_sid }
  it { is_expected.to have_attributes parent_sid: nil }

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
      subject(:presented) { described_class.new(child, requested_geo_area) }

      let(:child) { create :goods_nomenclature, parent: gn }

      it { is_expected.to have_attributes supplementary_measure_unit: /\w+ \(\w+\)/ }
    end

    context 'with export measure' do
      before { MeasureType::Operation.dataset.update trade_movement_code: 1 }

      it { is_expected.to have_attributes supplementary_measure_unit: nil }
    end
  end

  describe '#licences' do
    subject(:presented) { described_class.new(gn, requested_geo_area) }

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
      subject(:presented) { described_class.new(child, requested_geo_area) }

      let(:child) { create :goods_nomenclature, parent: gn }

      it { is_expected.to have_attributes licences: [certificate] }
    end

    context 'with export measure' do
      before { MeasureType::Operation.dataset.update trade_movement_code: 1 }

      it { is_expected.to have_attributes licences: [] }
    end
  end
end
