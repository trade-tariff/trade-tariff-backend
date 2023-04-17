RSpec.describe SearchSuggestion do
  describe '.fuzzy_search' do
    subject(:fuzzy_search) { described_class.fuzzy_search(query) }

    context 'when the query is a similar but mispelled word' do
      let(:query) { 'aluminum' }

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
end
