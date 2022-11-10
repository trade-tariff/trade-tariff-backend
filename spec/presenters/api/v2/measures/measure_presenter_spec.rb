RSpec.describe Api::V2::Measures::MeasurePresenter do
  subject(:presenter) { described_class.new(measure, measure.goods_nomenclature) }

  let(:measure) { create(:measure, :with_base_regulation, :with_measure_conditions) }

  describe '#legal_acts' do
    it 'will be mapped through the MeasureLegalActPresenter' do
      expect(presenter.legal_acts.first).to \
        be_instance_of(Api::V2::Measures::MeasureLegalActPresenter)
    end
  end

  context 'when measure has a generating regulation' do
    let(:measure) { create(:measure, :with_base_regulation) }

    describe '#measure_generating_legal_act' do
      it 'returns the MeasureLegalActPresenter' do
        expect(presenter.measure_generating_legal_act).to be_instance_of(Api::V2::Measures::MeasureLegalActPresenter)
      end
    end

    describe '#measure_generating_legal_act_id' do
      it 'has correct ID' do
        expect(presenter.measure_generating_legal_act_id).to eq(measure.measure_generating_regulation_id)
      end
    end
  end

  context 'when measure has a justification_legal_act' do
    let(:measure) { create(:measure, :with_justification_regulation) }

    describe '#measure_generating_legal_act' do
      it 'returns the MeasureLegalActPresenter' do
        expect(presenter.justification_legal_act).to be_instance_of(Api::V2::Measures::MeasureLegalActPresenter)
      end
    end

    describe '#measure_generating_legal_act_id' do
      it 'has correct ID' do
        expect(presenter.justification_legal_act_id).to eq(measure.justification_regulation_id)
      end
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
             measure:,
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

  describe '#universal_waiver_applies' do
    subject(:universal_waiver_applies) { described_class.new(measure, measure.goods_nomenclature).universal_waiver_applies }

    let(:measure) { create(:measure, :with_measure_conditions, certificate_type_code: '9', certificate_code: '99L') }

    it { is_expected.to be(true) }
  end

  describe '#preference_code' do
    subject(:preference_code) { described_class.new(measure, measure.goods_nomenclature).preference_code }

    let(:measure) { create(:measure, measure_type_id: '117') }

    it { is_expected.to be_a(PreferenceCode) }
  end

  describe '#preference_code_id' do
    subject(:preference_code) { described_class.new(measure, measure.goods_nomenclature).preference_code_id }

    let(:measure) { create(:measure, measure_type_id: '117') }

    it { is_expected.to eq('140') }
  end

  describe '#scheme_code' do
    subject(:scheme_code) { described_class.new(measure, measure.goods_nomenclature).scheme_code }

    context 'when a rules of origin measure with a matching scheme code' do
      let(:measure) { create(:measure, :with_measure_type, :tariff_preference, geographical_area_id:) }
      let(:geographical_area_id) { '1013' }

      it { is_expected.to eq('eu') }
    end

    context 'when a rules of origin measure with a non-matching scheme code' do
      let(:measure) { create(:measure, :with_measure_type, :tariff_preference, geographical_area_id:) }
      let(:geographical_area_id) { 'FOO' }

      it { is_expected.to be_nil }
    end

    context 'when not a rules of origin measure' do
      let(:measure) { create(:measure, :with_measure_type, :third_country) }

      it { is_expected.to be_nil }
    end
  end

  describe '#measure_condition_permutation_groups' do
    subject { presenter.measure_condition_permutation_groups }

    let(:measure) { create :measure, :with_measure_conditions }

    it { is_expected.not_to be_empty }
    it { is_expected.to all be_instance_of MeasureConditionPermutations::Group }
  end

  describe '#special_nature?' do
    context 'when measure has at least one measure condition with special nature use certificate' do
      let(:measure) { create(:measure, :with_measure_conditions, :with_special_nature) }

      it { is_expected.to be_special_nature }
    end

    context 'when measure has no measure conditions with special nature use certificate' do
      let(:measure) { create(:measure, :with_measure_conditions) }

      it { is_expected.not_to be_special_nature }
    end
  end

  describe '#authorised_use?' do
    context 'when measure has at least one measure condition with authorised use certificate' do
      let(:measure) { create(:measure, :with_measure_conditions, :with_authorised_use) }

      it { is_expected.to be_authorised_use }
    end

    context 'when measure has no measure conditions with authorised use certificate' do
      let(:measure) { create(:measure, :with_measure_conditions) }

      it { is_expected.not_to be_authorised_use }
    end
  end
end
