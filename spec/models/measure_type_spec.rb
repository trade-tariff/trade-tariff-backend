RSpec.describe MeasureType do
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

  describe '#meursing?' do
    shared_examples_for 'a meursing measure type' do |measure_type_id|
      subject(:measure_type) { build(:measure_type, measure_type_id: measure_type_id) }

      it { is_expected.to be_meursing }
    end

    it_behaves_like 'a meursing measure type', '672'
    it_behaves_like 'a meursing measure type', '673'
    it_behaves_like 'a meursing measure type', '674'

    context 'when not a meursing measure type' do
      subject(:measure_type) { build(:measure_type, measure_type_id: '142') }

      it { is_expected.not_to be_meursing }
    end
  end

  describe '#third_country?' do
    context 'when measure_type has measure_type_id of 103' do
      let(:measure_type) { build :measure_type, measure_type_id: '103' }

      it 'returns true' do
        expect(measure_type).to be_third_country
      end
    end

    context 'when measure_type has measure_type_id of 105' do
      let(:measure_type) { build :measure_type, measure_type_id: '105' }

      it 'returns true' do
        expect(measure_type).to be_third_country
      end
    end

    context 'when measure_type is non-third-country measure_type_id' do
      let(:measure_type) { build :measure_type, measure_type_id: 'foo' }

      it 'returns false' do
        expect(measure_type).not_to be_third_country
      end
    end
  end

  describe '#trade_remedy?' do
    context 'when measure_type has measure_type_id that is a defense measure type' do
      let(:measure_type) { build :measure_type, measure_type_id: MeasureType::DEFENSE_MEASURES.sample }

      it 'returns true' do
        expect(measure_type).to be_trade_remedy
      end
    end

    context 'when measure_type does not have a measure_type_id that is a defense measure type' do
      let(:measure_type) { build :measure_type, measure_type_id: 'foo' }

      it 'returns false' do
        expect(measure_type).not_to be_trade_remedy
      end
    end
  end

  describe '#expresses_unit?' do
    shared_examples 'an expressable measure' do |type_series_id|
      context "when measure_type has measure_type_series_id of #{type_series_id}" do
        let(:measure_type) { build :measure_type, measure_type_series_id: type_series_id }

        it 'returns true' do
          expect(measure_type).to be_expresses_unit
        end
      end
    end

    it_behaves_like 'an expressable measure', 'C'
    it_behaves_like 'an expressable measure', 'D'
    it_behaves_like 'an expressable measure', 'J'
    it_behaves_like 'an expressable measure', 'Q'

    context 'when measure_type has measure_type_series_id that does not express units' do
      let(:measure_type) { build :measure_type, measure_type_series_id: 'X' }

      it 'returns false' do
        expect(measure_type).not_to be_expresses_unit
      end
    end
  end

  describe '#vat?' do
    context 'when measure_type_id is a vat measure type id' do
      let(:measure_type) { build :measure_type, measure_type_id: MeasureType::VAT_TYPES.sample }

      it { expect(measure_type).to be_vat }
    end

    context 'when measure_type_id is not a vat measure type id' do
      let(:measure_type) { build :measure_type, measure_type_id: '103' }

      it { expect(measure_type).not_to be_vat }
    end
  end
end
