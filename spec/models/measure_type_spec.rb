require 'rails_helper'

describe MeasureType do
  describe 'validations' do
    # MT1 The measure type code must be unique.
    it { is_expected.to validate_uniqueness.of :measure_type_id }
    # MT2 The start date must be less than or equal to the end date.
    it { is_expected.to validate_validity_dates }
    # MT4 The referenced measure type series must exist.
    it { is_expected.to validate_presence.of(:measure_type_series) }
  end

  describe 'constants' do
    before do
      allow(TradeTariffBackend).to receive(:service).and_return(service)
    end

    context 'when the service is the UK version' do
      let(:service) { 'uk' }
      let(:excluded_types) { %w[442 SPL] }

      it 'defines the correct EXCLUDED_TYPES list' do
        expect(described_class.excluded_measure_types).to eq(excluded_types)
      end
    end

    context 'when the service is the XI version' do
      let(:service) { 'xi' }
      let(:excluded_types) do
        described_class::DEFAULT_EXCLUDED_TYPES + described_class::QUOTA_TYPES + described_class::NATIONAL_PR_TYPES
      end

      it 'defines the correct EXCLUDED_TYPES list' do
        expect(described_class.excluded_measure_types).to contain_exactly(*excluded_types)
      end
    end
  end

  describe '#excise?' do
    context 'measure type is Excise related' do
      let(:measure_type) { build :measure_type, measure_type_series_id: 'Q' }

      it 'returns true' do
        expect(measure_type).to be_excise
      end
    end

    context 'measure type is not Excise related' do
      let(:measure_type) { build :measure_type, measure_type_series_id: 'E' }

      it 'returns false' do
        expect(measure_type).not_to be_excise
      end
    end
  end

  describe '#third_country?' do
    context 'measure_type is third country' do
      let(:measure_type) { build :measure_type, measure_type_id: MeasureType::THIRD_COUNTRY }

      it 'returns true' do
        expect(measure_type).to be_third_country
      end
    end

    context 'measure_type is not third country' do
      let(:measure_type) { build :measure_type, measure_type_id: 'aaa' }

      it 'returns false' do
        expect(measure_type).not_to be_third_country
      end
    end
  end
end
