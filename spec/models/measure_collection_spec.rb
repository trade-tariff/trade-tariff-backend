RSpec.describe MeasureCollection do
  subject(:collection) { described_class.new(measures, filters) }

  describe '#filter' do
    before do
      allow(TradeTariffBackend).to receive(:service).and_return(service)
    end

    context 'when there are excise measures and the service is xi' do
      let(:measures) { [excise_measure] }
      let(:filters) { {} }
      let(:service) { 'xi' }

      let(:excise_measure) { create(:measure, :excise) }

      it { expect(collection.filter).to eq([]) }
    end

    context 'when there are excise measures and the service is uk' do
      let(:measures) { [excise_measure] }
      let(:filters) { {} }
      let(:service) { 'uk' }

      let(:excise_measure) { create(:measure, :excise) }

      it { expect(collection.filter).to eq([excise_measure]) }
    end

    context 'when there are no excise measures' do
      let(:measures) { [non_excise_measure] }
      let(:filters) { {} }
      let(:service) { 'uk' }

      let(:non_excise_measure) { create(:measure) }

      it { expect(collection.filter).to eq([non_excise_measure]) }
    end

    context 'when filtering by a specific country' do
      before do
        create(:geographical_area, geographical_area_id: 'IT')
      end

      let(:measures) { [italian_measure, non_italian_measure] }
      let(:filters) { { geographical_area_id: 'IT' } }
      let(:service) { 'uk' }

      let(:italian_measure) { create(:measure, geographical_area_id: 'IT') }
      let(:non_italian_measure) { create(:measure) }

      it { expect(collection.filter).to eq([italian_measure]) }
    end
  end
end
