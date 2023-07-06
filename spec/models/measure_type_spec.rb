RSpec.describe MeasureType do
  describe '.excluded_measure_types' do
    subject(:excluded_measure_types) { described_class.excluded_measure_types }

    before do
      allow(TradeTariffBackend).to receive(:service).and_return(service)
    end

    context 'when the service is the UK version' do
      let(:service) { 'uk' }
      let(:excluded_types) { %w[442 447 SPL] }

      it { is_expected.to eq(excluded_types) }
    end

    context 'when the service is the XI version' do
      let(:service) { 'xi' }

      let(:excluded_types) do
        %w[
          046
          122
          123
          143
          146
          147
          305
          306
          442
          447
          653
          654
          AHC
          AIL
          ATT
          CEX
          CHM
          COE
          COI
          CVD
          DAA
          DAB
          DAC
          DAE
          DAI
          DBA
          DBB
          DBC
          DBE
          DBI
          DCA
          DCC
          DCE
          DCH
          DDA
          DDB
          DDC
          DDD
          DDE
          DDF
          DDG
          DDJ
          DEA
          DFA
          DFB
          DFC
          DGC
          DHA
          DHC
          DHE
          DHG
          DPO
          EBA
          EBB
          EBJ
          ECM
          EDA
          EDB
          EDJ
          EEA
          EEF
          EFA
          EGA
          EGB
          EGJ
          EHC
          EHI
          EQC
          EWP
          EXA
          EXB
          EXC
          EXD
          FAA
          FAE
          FAI
          FBC
          FBG
          FCC
          HOP
          HSE
          IWP
          LBJ
          LDA
          LEA
          LEF
          LFA
          PHC
          PRE
          PRT
          QRC
          SFS
          SPL
          VTA
          VTE
          VTS
          VTZ
        ]
      end

      it { is_expected.to eq(excluded_types) }
    end
  end

  describe '#excise?' do
    context 'when measure type is Excise related' do
      subject(:measure_type) { build :measure_type, measure_type_series_id: 'Q' }

      it { is_expected.to be_excise }
    end

    context 'when measure type is not Excise related' do
      subject(:measure_type) { build :measure_type, measure_type_series_id: 'E' }

      it { is_expected.not_to be_excise }
    end
  end

  describe '#meursing?' do
    shared_examples_for 'a meursing measure type' do |measure_type_id|
      subject(:measure_type) { build(:measure_type, measure_type_id:) }

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
      subject(:measure_type) { build :measure_type, measure_type_id: '103' }

      it { is_expected.to be_third_country }
    end

    context 'when measure_type has measure_type_id of 105' do
      subject(:measure_type) { build :measure_type, measure_type_id: '105' }

      it { is_expected.to be_third_country }
    end

    context 'when measure_type is non-third-country measure_type_id' do
      subject(:measure_type) { build :measure_type, measure_type_id: 'foo' }

      it { expect(measure_type).not_to be_third_country }
    end
  end

  describe '#trade_remedy?' do
    context 'when measure_type has measure_type_id that is a defense measure type' do
      subject(:measure_type) { build :measure_type, measure_type_id: MeasureType::DEFENSE_MEASURES.sample }

      it { is_expected.to be_trade_remedy }
    end

    context 'when measure_type does not have a measure_type_id that is a defense measure type' do
      subject(:measure_type) { build :measure_type, measure_type_id: 'foo' }

      it { expect(measure_type).not_to be_trade_remedy }
    end
  end

  describe '#expresses_unit?' do
    shared_examples 'an expressable measure' do |type_series_id|
      context "when measure_type has measure_type_series_id of #{type_series_id}" do
        subject(:measure_type) { build :measure_type, measure_type_series_id: type_series_id }

        it { is_expected.to be_expresses_unit }
      end
    end

    it_behaves_like 'an expressable measure', 'C'
    it_behaves_like 'an expressable measure', 'D'
    it_behaves_like 'an expressable measure', 'J'
    it_behaves_like 'an expressable measure', 'Q'

    context 'when measure_type has measure_type_series_id that does not express units' do
      subject(:measure_type) { build :measure_type, measure_type_series_id: 'X' }

      it { expect(measure_type).not_to be_expresses_unit }
    end
  end

  describe '#vat?' do
    context 'when measure_type_id is a vat measure type id' do
      subject(:measure_type) { build :measure_type, measure_type_id: MeasureType::VAT_TYPES.sample }

      it { is_expected.to be_vat }
    end

    context 'when measure_type_id is not a vat measure type id' do
      subject(:measure_type) { build :measure_type, measure_type_id: '103' }

      it { expect(measure_type).not_to be_vat }
    end
  end

  describe '#rules_of_origin_apply?' do
    shared_examples 'a rules of origin measure' do |measure_type_id|
      subject(:measure_type) { build :measure_type, measure_type_id: }

      it { is_expected.to be_rules_of_origin_apply }
    end

    it_behaves_like 'a rules of origin measure', '142'
    it_behaves_like 'a rules of origin measure', '143'
    it_behaves_like 'a rules of origin measure', '145'
    it_behaves_like 'a rules of origin measure', '146'

    context 'when not a rules of origin measure' do
      subject(:measure_type) { build :measure_type, measure_type_id: 'X' }

      it { is_expected.not_to be_rules_of_origin_apply }
    end
  end

  describe '#authorised_use_provisions_submission?' do
    context 'when measure_type_id is an authorised_use_provisions_submission measure type id' do
      subject(:measure_type) { build :measure_type, measure_type_id: '464' }

      it { is_expected.to be_authorised_use_provisions_submission }
    end

    context 'when measure_type_id is not a authorised_use_provisions_submission  measure type id' do
      subject(:measure_type) { build :measure_type, measure_type_id: '103' }

      it { is_expected.not_to be_authorised_use_provisions_submission }
    end
  end

  describe '#supplementary?' do
    subject(:measure_type) { build :measure_type, measure_type_id: }

    shared_examples_for 'a supplementary measure' do |measure_type_id|
      subject(:measure_type) { build :measure_type, measure_type_id: }

      it { is_expected.to be_supplementary }
    end

    it_behaves_like 'a supplementary measure', '109'
    it_behaves_like 'a supplementary measure', '110'
    it_behaves_like 'a supplementary measure', '111'

    context 'when measure_type_id is not a supplementary measure type id' do
      let(:measure_type_id) { '103' }

      it { is_expected.not_to be_supplementary }
    end
  end
end
