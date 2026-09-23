RSpec.describe OpensearchRetrievalService do
  after { TradeTariffRequest.search_failures = nil }

  before do
    allow(ExpandSearchQueryService).to receive(:call)
  end

  it 'records failed retrieval before raising' do
    allow(TradeTariffBackend.search_client).to receive(:search).and_raise(Faraday::ConnectionFailed, 'unavailable')

    expect { described_class.call(query: 'handbag', as_of: Time.zone.today) }.to raise_error(Faraday::ConnectionFailed)
    expect(TradeTariffRequest.search_failures).to eq(%w[opensearch_failed])
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

    context 'with search_non_declarables' do
      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }

      it 'filters to declarable results by default' do
        described_class.call(query: 'toys', as_of: Time.zone.today)

        expect(TradeTariffBackend.search_client).to have_received(:search).with(
          hash_including(
            body: hash_including(
              query: hash_including(
                bool: hash_including(
                  must: include({ term: { declarable: true } }),
                ),
              ),
            ),
          ),
        )
      end

      it 'reads the default from AdminConfiguration when not overridden' do
        allow(AdminConfiguration).to receive(:enabled?).and_call_original
        allow(AdminConfiguration).to receive(:enabled?).with('search_non_declarables').and_return(true)

        described_class.call(query: 'toys', as_of: Time.zone.today)

        expect(TradeTariffBackend.search_client).to have_received(:search).with(
          hash_including(
            body: hash_including(
              query: hash_including(
                bool: hash_including(
                  must: satisfy { |clauses| clauses.none? { |c| c.dig(:term, :declarable) } },
                ),
              ),
            ),
          ),
        )
      end

      it 'omits the declarable filter when search_non_declarables: true is given explicitly' do
        described_class.call(query: 'toys', as_of: Time.zone.today, search_non_declarables: true)

        expect(TradeTariffBackend.search_client).to have_received(:search).with(
          hash_including(
            body: hash_including(
              query: hash_including(
                bool: hash_including(
                  must: satisfy { |clauses| clauses.none? { |c| c.dig(:term, :declarable) } },
                ),
              ),
            ),
          ),
        )
      end

      it 'uses an explicit search_non_declarables: false instead of reading AdminConfiguration' do
        allow(AdminConfiguration).to receive(:enabled?).and_call_original
        allow(AdminConfiguration).to receive(:enabled?).with('search_non_declarables').and_return(true)

        described_class.call(query: 'toys', as_of: Time.zone.today, search_non_declarables: false)

        expect(AdminConfiguration).not_to have_received(:enabled?).with('search_non_declarables')
        expect(TradeTariffBackend.search_client).to have_received(:search).with(
          hash_including(
            body: hash_including(
              query: hash_including(
                bool: hash_including(
                  must: include({ term: { declarable: true } }),
                ),
              ),
            ),
          ),
        )
      end
    end

    context 'with filter prefixes' do
      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }
      let(:prefix_clause) do
        {
          bool: {
            should: [
              { prefix: { goods_nomenclature_item_id: '9503' } },
              { prefix: { goods_nomenclature_item_id: '9504' } },
            ],
            minimum_should_match: 1,
          },
        }
      end
      let(:sent_must_clauses) { [] }

      before do
        allow(TradeTariffBackend.search_client).to receive(:search) do |request|
          sent_must_clauses << request.dig(:body, :query, :bool, :must)
          opensearch_response
        end
      end

      it 'adds prefix filters to every query it sends' do
        described_class.call(query: 'toys', as_of: Time.zone.today, filter_prefixes: %w[9503 9504])

        expect(sent_must_clauses).to all(include(prefix_clause))
      end

      it 'sends a second query without the text clause when the first query has no hits', :aggregate_failures do
        described_class.call(query: 'toys', as_of: Time.zone.today, filter_prefixes: %w[9503 9504])

        expect(sent_must_clauses.size).to eq(2)
        expect(sent_must_clauses.first).to include(a_hash_including(:multi_match))
        expect(sent_must_clauses.last).not_to include(a_hash_including(:multi_match))
      end

      context 'when the first query has hits' do
        let(:opensearch_response) do
          { 'hits' => { 'hits' => [{ '_score' => 3.2, '_source' => { 'goods_nomenclature_sid' => 1, 'goods_nomenclature_item_id' => '9503001000' } }] } }
        end

        it 'sends one query only' do
          described_class.call(query: 'toys', as_of: Time.zone.today, filter_prefixes: %w[9503 9504])

          expect(sent_must_clauses.size).to eq(1)
        end
      end
    end

    context 'without filter prefixes' do
      let(:opensearch_response) { { 'hits' => { 'hits' => [] } } }

      it 'sends one query only when it has no hits' do
        described_class.call(query: 'toys', as_of: Time.zone.today)

        expect(TradeTariffBackend.search_client).to have_received(:search).once
      end
    end
  end

  # These examples run real queries against the goods nomenclature index. A
  # caller that filters to a heading must get the heading's codes back when no
  # query word matches them. When some codes match, only those codes come back,
  # so codes with no match cannot push better candidates out of a fused result.
  describe 'filter prefix results' do
    let(:documents) do
      [
        { goods_nomenclature_sid: 9_730_801, goods_nomenclature_item_id: '7308100000', description: 'bridges and bridge sections' },
        { goods_nomenclature_sid: 9_730_802, goods_nomenclature_item_id: '7308200000', description: 'towers and lattice masts' },
        { goods_nomenclature_sid: 9_730_803, goods_nomenclature_item_id: '7308300000', description: 'doors windows and their frames' },
        { goods_nomenclature_sid: 9_730_901, goods_nomenclature_item_id: '7309000000', description: 'reservoirs tanks and vats with bridges' },
      ]
    end

    before do
      documents.each { |document| index_goods_nomenclature_document(**document) }
      refresh_search_indexes
    end

    after do
      documents.each { |document| delete_goods_nomenclature_document(document[:goods_nomenclature_sid]) }
    end

    def item_ids_for(query, filter_prefixes)
      described_class.call(query: query, as_of: Time.zone.today, filter_prefixes: filter_prefixes)
                     .results.map(&:goods_nomenclature_item_id)
    end

    it 'returns every code in the prefix when no query word matches' do
      expect(item_ids_for('brace', %w[7308])).to contain_exactly('7308100000', '7308200000', '7308300000')
    end

    it 'returns only the matching codes when some codes in the prefix match' do
      expect(item_ids_for('bridges', %w[7308])).to eq(%w[7308100000])
    end

    it 'does not return a code outside the prefix' do
      expect(item_ids_for('brace', %w[7308])).not_to include('7309000000')
    end

    it 'returns no codes when there are no prefixes and no query word matches' do
      expect(item_ids_for('brace', [])).to be_empty
    end
  end
end
