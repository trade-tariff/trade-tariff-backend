RSpec.describe Api::V2::Commodities::CommodityPresenter do
  subject(:presenter) { described_class.new(commodity.reload, measures) }

  let(:commodity) do
    create(
      :commodity,
      :with_indent,
      :with_chapter,
      :with_heading,
      :with_description,
      :declarable,
    )
  end

  let(:zero_mfn_measure) do
    create(
      :measure,
      :with_measure_components,
      :with_measure_type,
      :third_country,
      duty_amount: 0,
    )
  end

  let(:non_zero_mfn_measure) do
    create(
      :measure,
      :with_measure_components,
      :with_measure_type,
      :third_country,
      duty_amount: 1,
    )
  end

  let(:non_mfn_measure) do
    create(
      :measure,
      :with_measure_components,
      :with_measure_type,
    )
  end

  describe '#third_country_measures' do
    let(:measures) { [non_mfn_measure, zero_mfn_measure] }

    it { expect(presenter.third_country_measures).to eq([zero_mfn_measure]) }
  end

  describe '#zero_mfn_duty?' do
    context 'when all mfn duties are zero' do
      let(:measures) { [zero_mfn_measure, zero_mfn_measure] }

      it { is_expected.to be_zero_mfn_duty }
    end

    context 'when at least one mfn duty is non-zero' do
      let(:measures) { [zero_mfn_measure, non_zero_mfn_measure] }

      it { is_expected.not_to be_zero_mfn_duty }
    end

    context 'when no mfn duty is zero' do
      let(:measures) { [non_zero_mfn_measure, non_zero_mfn_measure] }

      it { is_expected.not_to be_zero_mfn_duty }
    end

    context 'when no mfn duties are passed' do
      let(:measures) { [] }

      it { is_expected.not_to be_zero_mfn_duty }
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
end
