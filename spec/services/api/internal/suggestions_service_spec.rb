RSpec.describe Api::Internal::SuggestionsService do
  describe '#call' do
    context 'when blank query' do
      it 'returns empty data' do
        result = described_class.new(q: '').call
        expect(result).to eq(data: [])
      end
    end

    context 'when nil query' do
      it 'returns empty data' do
        result = described_class.new(q: nil).call
        expect(result).to eq(data: [])
      end
    end

    context 'when rogue query' do
      it 'returns empty data' do
        result = described_class.new(q: 'gift').call
        expect(result).to eq(data: [])
      end
    end

    context 'when valid query with results' do
      let(:opensearch_response) do
        {
          'hits' => {
            'hits' => [
              {
                '_score' => 15.3,
                '_source' => {
                  'goods_nomenclature_sid' => 12_345,
                  'value' => 'aluminium wire',
                  'suggestion_type' => 'search_reference',
                  'priority' => 1,
                  'goods_nomenclature_class' => 'Heading',
                },
              },
            ],
          },
        }
      end

      before do
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      end

      it 'returns serialized search suggestions' do
        result = described_class.new(q: 'aluminium', as_of: Time.zone.today.iso8601).call

        expect(result[:data].length).to eq(1)
        expect(result[:data][0][:type]).to eq(:search_suggestion)
        expect(result[:data][0][:attributes][:value]).to eq('aluminium wire')
        expect(result[:data][0][:attributes][:score]).to eq(15.3)
        expect(result[:data][0][:attributes][:query]).to eq('aluminium')
        expect(result[:data][0][:attributes][:suggestion_type]).to eq('search_reference')
      end

      it 'queries the SearchSuggestionQuery with processed query and date' do
        described_class.new(q: 'aluminium', as_of: Time.zone.today.iso8601).call

        expect(TradeTariffBackend.search_client).to have_received(:search).with(
          hash_including(index: Search::SearchSuggestionsIndex.new.name),
        )
      end
    end

    context 'when valid query with no results' do
      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }

      before do
        allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
      end

      it 'returns empty data' do
        result = described_class.new(q: 'nonexistent').call
        expect(result[:data]).to eq([])
      end
    end
  end
end
