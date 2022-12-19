RSpec.describe Api::Beta::SearchService do
  # rubocop:disable RSpec/MultipleMemoizedHelpers
  describe '#call' do
    subject(:search_result) { described_class.new(search_query, filters: {}, spell: '1').call }

    context 'when the search query is an empty string' do
      let(:search_query) { '' }

      it { expect(search_result.empty_query).to eq(true) }
    end

    context 'when the search query is `ricotta`' do
      let(:search_query) { 'ricotta' }
      let(:opensearch_result) do
        fixture_file = file_fixture('beta/search/goods_nomenclatures/single_hit.json')

        Hashie::TariffMash.new(JSON.parse(fixture_file.read))
      end
      let(:search_query_parser_service) { instance_double('Api::Beta::SearchQueryParserService', call: search_query_parser_result) }
      let(:search_query_parser_result) { build(:search_query_parser_result, :single_hit) }
      let(:goods_nomenclature_query) { build(:goods_nomenclature_query, :single_hit) }
      let(:expected_search_args) do
        {
          body: {
            size: '10',
            query: {
              bool: {
                filter: {
                  bool: {
                    must: [
                      { term: { declarable: true } },
                    ],
                  },
                },
                must: [
                  {
                    multi_match: {
                      fields: [
                        'search_intercept_terms^15',
                        'search_references^12',
                        'ancestor_2_description_indexed^8',
                        'description_indexed^6',
                        'ancestor_3_description_indexed^4',
                        'ancestor_4_description_indexed^4',
                        'ancestor_5_description_indexed^4',
                        'ancestor_6_description_indexed^4',
                        'ancestor_7_description_indexed^4',
                        'ancestor_8_description_indexed^4',
                        'ancestor_9_description_indexed^4',
                        'ancestor_10_description_indexed^4',
                        'ancestor_11_description_indexed^4',
                        'ancestor_12_description_indexed^4',
                        'ancestor_13_description_indexed^4',
                        'goods_nomenclature_item_id',
                      ],
                      fuzziness: 0.1,
                      prefix_length: 2,
                      query: 'ricotta',
                      tie_breaker: 0.3,
                      type: 'best_fields',
                    },
                  },
                ],
              },
            },
          },
          index: 'tariff-test-goods_nomenclatures-uk',
        }
      end
      let(:expected_serialized_result) do
        fixture_file = file_fixture('beta/search/goods_nomenclatures/serialized_result.json')

        JSON.parse(fixture_file.read)
      end

      before do
        allow(TradeTariffBackend.v2_search_client).to receive(:search).and_return(opensearch_result)
        allow(Api::Beta::SearchQueryParserService).to receive(:new).and_return(search_query_parser_service)
        allow(Api::Beta::GoodsNomenclatureFilterGeneratorService).to receive(:new).and_call_original
        allow(Beta::Search::GoodsNomenclatureQuery).to receive(:build).and_return(goods_nomenclature_query)
        allow(Beta::Search::OpenSearchResult::WithHits).to receive(:build).and_call_original

        search_result
      end

      it { expect(Api::Beta::SearchQueryParserService).to have_received(:new).with('ricotta', spell: '1', should_search: true) }
      it { expect(TradeTariffBackend.v2_search_client).to have_received(:search).with(expected_search_args) }
      it { expect(Beta::Search::OpenSearchResult::WithHits).to have_received(:build).with(opensearch_result, search_query_parser_result, goods_nomenclature_query, nil) }
      it { expect(Beta::Search::GoodsNomenclatureQuery).to have_received(:build).with(search_query_parser_result, {}) }
      it { expect(search_result).to be_a(Beta::Search::OpenSearchResult) }
    end

    shared_examples_for 'a redirecting search result' do |search_query|
      subject(:search_result) { described_class.new(search_query).call }

      before do
        create(:search_reference, title: 'raw')
      end

      it { is_expected.to be_redirect }
    end

    it_behaves_like 'a redirecting search result', '01' # Chapter
    it_behaves_like 'a redirecting search result', '0101' # Heading
    it_behaves_like 'a redirecting search result', '010129' # Subheading
    it_behaves_like 'a redirecting search result', '01012960' # Subheading
    it_behaves_like 'a redirecting search result', '0101210000' # Commodity
    it_behaves_like 'a redirecting search result', '0101210000-80' # Subheading
    it_behaves_like 'a redirecting search result', '0101210000380' # Heading
    it_behaves_like 'a redirecting search result', '010121000038123' # Heading
    it_behaves_like 'a redirecting search result', 'raw'

    context 'when the search query has multiple corresponding search references' do
      let(:search_query) { 'same' }

      before do
        create(:heading, :with_search_reference, title: 'same')
        create(:commodity, :with_search_reference, title: 'same')

        search_result = Hashie::TariffMash.new(
          JSON.parse(
            file_fixture('beta/search/goods_nomenclatures/single_hit.json').read,
          ),
        )
        allow(TradeTariffBackend.v2_search_client).to receive(:search).and_return(search_result)
        allow(Api::Beta::SearchQueryParserService).to receive(:new).and_return(
          instance_double('Api::Beta::SearchQueryParserService', call: build(:search_query_parser_result)),
        )
        allow(Beta::Search::GoodsNomenclatureQuery).to receive(:build).and_return(build(:goods_nomenclature_query))
        allow(Beta::Search::OpenSearchResult::WithHits).to receive(:build).and_call_original

        search_result
      end

      it { is_expected.not_to be_redirect }
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers
end
