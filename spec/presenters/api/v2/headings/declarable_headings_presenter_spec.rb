RSpec.describe Api::V2::Headings::DeclarableHeadingPresenter do
  subject(:presenter) { described_class.new(heading, measures) }

  let(:heading) { create(:heading, :declarable) }
  let(:measures) { [create(:measure)] }

  describe '#meursing_code?' do
    context 'when the import measures have meursing codes' do
      let(:measures) { [create(:measure, :with_measure_components, :with_meursing)] }

      it { is_expected.to be_meursing_code }
    end

    context 'when the import measures do not have meursing codes' do
      let(:measures) { [create(:measure, :with_measure_components, :without_meursing)] }

      it { is_expected.not_to be_meursing_code }
    end
  end

  describe '#meursing_code' do
    it { expect(presenter.method(:meursing_code)).to eq(presenter.method(:meursing_code?)) }
  end

  describe '#zero_mfn_duty?' do
    let(:zero_mfn_measure) { create(:measure, :with_measure_components, :third_country, duty_amount: 0) }
    let(:non_zero_mfn_measure) { create(:measure, :with_measure_components, :third_country, duty_amount: 1) }
    let(:non_mfn_measure) { create(:measure) }

    context 'when some of the mfn measures have zero duties' do
      let(:measures) { [zero_mfn_measure, non_zero_mfn_measure, non_mfn_measure] }

      it { is_expected.not_to be_zero_mfn_duty }
    end

    context 'when all of the mfn measures have zero duties' do
      let(:measures) { [zero_mfn_measure, non_mfn_measure] }

      it { is_expected.to be_zero_mfn_duty }
    end

    context 'when none of the mfn measures have zero duties' do
      let(:measures) { [non_zero_mfn_measure, non_mfn_measure] }

      it { is_expected.not_to be_zero_mfn_duty }
    end
  end

  describe '#trade_remedies?' do
    let(:trade_remedy_measure) { create(:measure, :trade_remedy) }
    let(:non_trade_remedy_measure) { create(:measure) }

    context 'when one of the measures is a trade remedy measure type' do
      let(:measures) { [trade_remedy_measure, non_trade_remedy_measure] }

      it { is_expected.to be_trade_remedies }
    end

    context 'when none of the measures is a trade remedy measure type' do
      let(:measures) { [non_trade_remedy_measure] }

      it { is_expected.not_to be_trade_remedies }
    end
  end

  describe '#entry_price_system?' do
    before do
      allow(TradeTariffBackend).to receive(:service).and_return(service)
    end

    let(:entry_price_measure) { create(:measure, :with_measure_conditions, :with_entry_price_system) }
    let(:non_entry_price_measure) { create(:measure, :with_measure_conditions, :without_entry_price_system) }

    context 'when on the uk service' do
      let(:service) { 'uk' }

      let(:measures) { [entry_price_measure, non_entry_price_measure] }

      it { is_expected.not_to be_entry_price_system }
    end

    context 'when one of the measures uses the entry price system and on the xi service' do
      let(:service) { 'xi' }
      let(:measures) { [entry_price_measure, non_entry_price_measure] }

      it { is_expected.to be_entry_price_system }
    end

    context 'when none of the measures uses the entry price system and on the xi service' do
      let(:service) { 'xi' }
      let(:measures) { [non_entry_price_measure] }

      it { is_expected.not_to be_entry_price_system }
    end
  end

  describe '#applicable_additional_codes' do
    let(:collaborator) { instance_double(ApplicableAdditionalCodeService, call: {}) }

    before do
      allow(ApplicableAdditionalCodeService).to receive(:new).and_return(collaborator)
    end

    it 'calls the ApplicableAdditionalCodeService' do
      presenter.applicable_additional_codes

      expect(ApplicableAdditionalCodeService).to have_received(:new).with(
        [an_instance_of(Api::V2::Measures::MeasurePresenter)],
      )
    end

    it { expect(presenter.applicable_additional_codes).to eq({}) }
  end

  describe '#applicable_measure_units' do
    let(:collaborator) { instance_double(MeasureUnitService, call: {}) }

    before do
      allow(MeasureUnitService).to receive(:new).and_return(collaborator)
    end

    it 'calls the ApplicableAdditionalCodeService' do
      presenter.applicable_measure_units

      expect(MeasureUnitService).to have_received(:new).with([])
    end

    it { expect(presenter.applicable_measure_units).to eq({}) }
  end

  describe '#applicable_vat_options' do
    let(:collaborator) { instance_double(ApplicableVatOptionsService, call: {}) }

    before do
      allow(ApplicableVatOptionsService).to receive(:new).and_return(collaborator)
    end

    it 'calls the ApplicableAdditionalCodeService' do
      presenter.applicable_vat_options

      expect(ApplicableVatOptionsService).to have_received(:new).with(
        [an_instance_of(Api::V2::Measures::MeasurePresenter)],
      )
    end

    it { expect(presenter.applicable_vat_options).to eq({}) }
  end
end
