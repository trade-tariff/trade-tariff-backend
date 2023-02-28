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
      expect(fuzzy_search.pluck(:score)).to include_json(
        [
          be_within(0.2).of(0.411765),
          be_within(0.2).of(0.411765),
          be_within(0.2).of(0.411765),
          be_within(0.2).of(0.3),
        ],
      )
    end

    it 'returns search suggestions with a query' do
      expect(fuzzy_search.pluck(:query)).to all(eq(query))
    end

    context 'when the query is a 10 digit number' do
      let(:query) { '1234567890' }

      before do
        create(:search_suggestion, id: 'abc', value: '1234567890')
        create(:search_suggestion, id: 'def', value: '1234567890')
        create(:search_suggestion, value: '1234567891')
      end

      it 'returns search suggestions' do
        expect(fuzzy_search.pluck(:value)).to eq(
          %w[
            1234567890
          ],
        )
      end
    end
  end
end
