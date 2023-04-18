RSpec.describe SearchSuggestion do
  describe '#goods_nomenclature' do
    subject(:goods_nomenclature) { create(:search_suggestion, goods_nomenclature: create(:heading)).goods_nomenclature }

    it { is_expected.to be_a(Heading) }
  end

  describe '.fuzzy_search' do
    subject(:fuzzy_search) { described_class.fuzzy_search(query) }

    context 'when the query is a similar but mispelled word' do
      let(:query) { 'alu' }

      before do
        create(:search_suggestion, :search_reference, value: 'aluminium wire')
        create(:search_suggestion, :search_reference, value: 'nuts, aluminium')
        create(:search_suggestion, :search_reference, value: 'bars - aluminium')
        create(:search_suggestion, :search_reference, value: 'alu')
        create(:search_suggestion, :search_reference, value: 'test')
      end

      it 'returns search suggestions' do
        expect(fuzzy_search.pluck(:value)).to eq(
          [
            'alu',
            'aluminium wire',
            'nuts, aluminium',
            'bars - aluminium',
          ],
        )
      end

      it 'returns search suggestions with a score' do
        expect(fuzzy_search.pluck(:score)).to include_json(
          [
            be_within(0.2).of(1.0),
            be_within(0.2).of(0.1875),
            be_within(0.2).of(0.1875),
            be_within(0.2).of(0.1875),
          ],
        )
      end

      it 'returns search suggestions with a query' do
        expect(fuzzy_search.pluck(:query)).to all(eq(query))
      end
    end

    context 'when the query is a 10 digit number' do
      let(:query) { '1234567890' }

      before do
        create(:search_suggestion, :goods_nomenclature, id: 'abc', value: '1234567890')
        create(:search_suggestion, :goods_nomenclature, id: 'def', value: '1234567890')
        create(:search_suggestion, :goods_nomenclature, value: '1234567891')
      end

      it 'returns search suggestions' do
        expect(fuzzy_search.pluck(:value)).to eq(
          %w[
            1234567890
          ],
        )
      end
    end

    context 'when the query is a number that is not 10 digits' do
      let(:query) { '123' }

      before do
        create(:search_suggestion, :goods_nomenclature, value: '1234567890')
        create(:search_suggestion, :goods_nomenclature, value: '1234')
        create(:search_suggestion, :goods_nomenclature, value: '1235')
        create(:search_suggestion, :goods_nomenclature, value: '1234567891')
      end

      it 'returns search suggestions' do
        expect(fuzzy_search.pluck(:value)).to eq(
          %w[
            1234
            1235
            1234567890
            1234567891
          ],
        )
      end
    end

    context 'when the query is an empty string' do
      let(:query) { '' }

      before do
        create(:search_suggestion, value: '') # control
      end

      it 'returns an empty array' do
        expect(fuzzy_search).to be_empty
      end
    end

    context 'when the query is nil' do
      let(:query) { nil }

      it 'returns an empty array' do
        expect(fuzzy_search).to be_empty
      end
    end
  end

  describe '.by_value' do
    subject(:by_value) { described_class.by_value('gold ore') }

    context 'when the search suggestion exists' do
      let!(:search_suggestion) { create(:search_suggestion, :search_reference, value: 'gold ore') }

      it { is_expected.to eq([search_suggestion]) }
    end

    context 'when the search suggestion does not exist' do
      it { is_expected.to be_empty }
    end
  end

  describe '.goods_nomenclature_type' do
    subject(:goods_nomenclature_type) { described_class.goods_nomenclature_type.sql }

    it { is_expected.to include("WHERE (\"type\" = 'goods_nomenclature')") }
  end

  describe '.text_type' do
    subject(:text_type) { described_class.text_type.select_map(:value) }

    before do
      create(:search_suggestion, :search_reference, value: 'gold ore')
      create(:search_suggestion, :full_chemical_name, value: 'ore')
      create(:search_suggestion, value: 'null type')

      allow(TradeTariffBackend).to receive(:full_chemical_search_enabled?).and_return(full_chemical_search_enabled)
    end

    context 'when full chemical search is enabled' do
      let(:full_chemical_search_enabled) { true }

      it { is_expected.to eq(['gold ore', 'ore']) }
    end

    context 'when full chemical search is disabled' do
      let(:full_chemical_search_enabled) { false }

      it { is_expected.to eq(['gold ore', 'null type']) }
    end
  end

  describe '.numeric_type' do
    subject(:numeric_type) { described_class.numeric_type.select_map(:value) }

    before do
      create(:search_suggestion, :goods_nomenclature, value: '1234')
      create(:search_suggestion, :full_chemical_cus, value: '0154438-3')
      create(:search_suggestion, :full_chemical_cas, value: '8028-66-8')
      create(:search_suggestion, value: '1235')

      allow(TradeTariffBackend).to receive(:full_chemical_search_enabled?).and_return(full_chemical_search_enabled)
    end

    context 'when full chemical search is enabled' do
      let(:full_chemical_search_enabled) { true }

      it { is_expected.to eq(%w[1234 0154438-3 8028-66-8]) }
    end

    context 'when full chemical search is disabled' do
      let(:full_chemical_search_enabled) { false }

      it { is_expected.to eq(%w[1234 1235]) }
    end
  end
end
