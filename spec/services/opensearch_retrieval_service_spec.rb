RSpec.describe OpensearchRetrievalService do
  before do
    allow(ExpandSearchQueryService).to receive(:call)
  end

  describe '#call' do
    let(:opensearch_response) do
      {
        'hits' => {
          'hits' => [
            {
              '_score' => 12.5,
              '_source' => {
                'goods_nomenclature_sid' => 1,
                'goods_nomenclature_item_id' => '0100000000',
                'producline_suffix' => '80',
                'goods_nomenclature_class' => 'Chapter',
                'description' => 'live animals',
                'formatted_description' => 'Live animals',
                'self_text' => nil,
                'classification_description' => 'Live animals',
                'full_description' => 'Live animals',
                'heading_description' => nil,
                'declarable' => false,
              },
            },
          ],
        },
      }
    end

    before do
      allow(TradeTariffBackend.search_client).to receive(:search).and_return(opensearch_response)
    end

    it 'returns a Result with results and expanded_query' do
      result = described_class.call(query: 'animals', expanded_query: 'live animals', as_of: Time.zone.today)

      expect(result).to be_a(described_class::Result)
      expect(result.results.length).to eq(1)
      expect(result.results.first.goods_nomenclature_item_id).to eq('0100000000')
      expect(result.results.first.score).to eq(12.5)
      expect(result.expanded_query).to eq('live animals')
    end

    it 'does not expand queries itself' do
      described_class.call(query: 'animals', as_of: Time.zone.today)

      expect(ExpandSearchQueryService).not_to have_received(:call)
    end

    context 'when opensearch returns empty hits' do
      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }

      it 'returns empty results' do
        result = described_class.call(query: 'nonexistent', as_of: Time.zone.today)

        expect(result.results).to be_empty
      end
    end

    context 'with filter prefixes' do
      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }

      it 'adds prefix filters to the query' do
        described_class.call(query: 'toys', as_of: Time.zone.today, filter_prefixes: %w[9503 9504])

        expect(TradeTariffBackend.search_client).to have_received(:search).with(
          hash_including(
            body: hash_including(
              query: hash_including(
                bool: hash_including(
                  must: include(
                    bool: hash_including(
                      minimum_should_match: 1,
                      should: contain_exactly(
                        { prefix: { goods_nomenclature_item_id: '9503' } },
                        { prefix: { goods_nomenclature_item_id: '9504' } },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
      end
    end
  end
end
