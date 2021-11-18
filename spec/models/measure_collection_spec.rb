RSpec.describe MeasureCollection do
  subject(:collection) { described_class.new(measures, declarable) }

  let(:declarable) { build(:commodity) }

  describe '#filter' do
    before do
      allow(TradeTariffBackend).to receive(:service).and_return(service)
    end

    let(:service) { 'uk' }

    let(:excise_measure) { create(:measure, :excise) }
    let(:non_excise_measure) { create(:measure) }

    context 'when there are excise measures and the service is xi' do
      let(:measures) { [excise_measure] }
      let(:service) { 'xi' }

      it { expect(collection.filter).to eq([]) }
    end

    context 'when there are excise measures and the service is uk' do
      let(:measures) { [excise_measure] }
      let(:service) { 'uk' }

      it { expect(collection.filter).to eq([excise_measure]) }
    end

    context 'when there are no excise measures' do
      let(:measures) { [non_excise_measure] }

      it { expect(collection.filter).to eq([non_excise_measure]) }
    end
  end
end
