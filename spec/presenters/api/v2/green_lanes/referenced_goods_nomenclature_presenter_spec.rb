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
end
