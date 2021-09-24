RSpec.describe Api::V2::Measures::MeasurePresenter do
  subject(:presenter) { described_class.new(measure, measure.goods_nomenclature) }

  let(:measure) { create(:measure) }

  describe '#legal_acts' do
    it 'will be mapped through the MeasureLegalActPresenter' do
      expect(presenter.legal_acts.first).to \
        be_instance_of(Api::V2::Measures::MeasureLegalActPresenter)
    end
  end

  describe 'exclusions' do
    let(:gb) { create(:geographical_area, geographical_area_id: 'GB') }
    let(:xi) { create(:geographical_area, geographical_area_id: 'XI') }

    let(:xi_exclusion) do
      create(:measure_excluded_geographical_area,
             measure_sid: measure.measure_sid,
             geographical_area_sid: xi.geographical_area_sid,
             excluded_geographical_area: xi.geographical_area_id,
             measure: measure,
             geographical_area: xi)
    end

    before do
      allow(MeasureTypeExclusion).to \
        receive(:find)
        .with(measure.measure_type_id, measure.geographical_area_id)
        .and_return(excluded_countries)
    end

    describe '#excluded_countries' do
      subject { presenter.excluded_countries }

      context 'with measure type exclusions' do
        let(:excluded_countries) { [gb.geographical_area_id] }

        it { is_expected.to include(gb) }
        it { is_expected.not_to include(xi) }
      end

      context 'with directly excluded countries' do
        let(:excluded_countries) { [] }

        before { xi_exclusion }

        it { is_expected.to include(xi) }
        it { is_expected.not_to include(gb) }
      end

      context 'with both measure type and directly excluded countries' do
        let(:excluded_countries) { [gb.geographical_area_id] }

        before { xi_exclusion }

        it { is_expected.to include(gb) }
        it { is_expected.to include(xi) }
      end
    end

    describe '#excluded_country_ids' do
      subject { presenter.excluded_country_ids }

      context 'with measure type exclusions' do
        let(:excluded_countries) { [gb.geographical_area_id] }

        it { is_expected.to include('GB') }
        it { is_expected.not_to include('XI') }
      end

      context 'with directly excluded countries' do
        let(:excluded_countries) { [] }

        before { xi_exclusion }

        it { is_expected.to include('XI') }
        it { is_expected.not_to include('GB') }
      end

      context 'with both measure type and directly excluded countries' do
        let(:excluded_countries) { [gb.geographical_area_id] }

        before { xi_exclusion }

        it { is_expected.to include('GB') }
        it { is_expected.to include('XI') }
      end
    end
  end
end
