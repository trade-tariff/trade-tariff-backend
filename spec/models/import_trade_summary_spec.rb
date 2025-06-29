RSpec.describe ImportTradeSummary do
  describe 'attributes' do
    it { is_expected.to respond_to :basic_third_country_duty }
    it { is_expected.to respond_to :preferential_tariff_duty }
    it { is_expected.to respond_to :preferential_quota_duty }
  end

  describe '#id' do
    subject(:id) { described_class.build([build(:measure)]).id }

    it { is_expected.to be_present }
  end

  describe '#basic_third_country_duty' do
    subject(:basic_third_country_duty) { described_class.build(import_measures).basic_third_country_duty }

    context 'when there are third country measures' do
      let(:import_measures) { create_list(:measure, 1, :third_country, :erga_omnes, :with_measure_components) }

      it { is_expected.to be_present }
    end

    context 'when there are no third country measures' do
      let(:import_measures) { [] }

      it { is_expected.to be_nil }
    end
  end

  describe '#preferential_tariff_duty' do
    subject(:preferential_tariff_duty) { described_class.build(import_measures).preferential_tariff_duty }

    context 'when there are tariff preference measures' do
      let(:import_measures) { create_list(:measure, 1, :tariff_preference, :with_measure_components) }

      it { is_expected.to be_present }
    end

    context 'when there are no tariff preference measures' do
      let(:import_measures) { [] }

      it { is_expected.to be_nil }
    end
  end

  describe '#preferential_quota_duty' do
    subject(:preferential_quota_duty) { described_class.build(import_measures).preferential_quota_duty }

    context 'when there are quota measures' do
      let(:import_measures) { create_list(:measure, 1, :preferential_quota, :with_measure_components) }

      it { is_expected.to be_present }
    end

    context 'when there are no quota measures' do
      let(:import_measures) { [] }

      it { is_expected.to be_nil }
    end
  end
end
