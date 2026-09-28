RSpec.describe ImportTradeSummary do
  describe '#basic_third_country_duty' do
    subject(:basic_third_country_duty) { described_class.build(import_measures).basic_third_country_duty }

    context 'when there are no third country measures' do
      let(:import_measures) { [] }

      it { is_expected.to be_nil }
    end
  end

  describe '#preferential_tariff_duty' do
    subject(:preferential_tariff_duty) { described_class.build(import_measures).preferential_tariff_duty }

    context 'when there are no tariff preference measures' do
      let(:import_measures) { [] }

      it { is_expected.to be_nil }
    end
  end

  describe '#preferential_quota_duty' do
    subject(:preferential_quota_duty) { described_class.build(import_measures).preferential_quota_duty }

    context 'when there are no quota measures' do
      let(:import_measures) { [] }

      it { is_expected.to be_nil }
    end
  end
end
