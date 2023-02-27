RSpec.describe SearchSuggestion do
  describe '.fuzzy_search' do
    subject(:fuzzy_search) { described_class.fuzzy_search(query) }

    let(:query) { 'aluminum' }

    before do
      create(:search_suggestion, value: 'aluminium wire')
      create(:search_suggestion, value: 'nuts, aluminium')
      create(:search_suggestion, value: 'bars - aluminium')
      create(:search_suggestion, value: 'alu')
      create(:search_suggestion, value: 'test')
    end

    it 'returns search suggestions' do
      expect(fuzzy_search.pluck(:value)).to eq(
        [
          'aluminium wire',
          'nuts, aluminium',
          'bars - aluminium',
          'alu',
        ],
      )
    end

    it 'returns search suggestions with a score' do
      expect(fuzzy_search.pluck(:score)).to eq(
        [
          0.411765,
          0.411765,
          0.411765,
          0.3,
        ],
      )
    end

    it 'returns search suggestions with a query' do
      expect(fuzzy_search.pluck(:query)).to all(eq(query))
    end
  end
end
