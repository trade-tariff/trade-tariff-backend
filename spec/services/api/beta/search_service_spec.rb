RSpec.describe Api::Beta::SearchService do
  describe '#call' do
    subject(:call) { described_class.new('ricotta').call }

    before do
      allow(TradeTariffBackend.v2_search_client).to receive(:search).and_return(search_result)
      allow(Api::Beta::SearchQueryParserService).to receive(:new).and_return(search_query_parser_service)
      allow(Beta::Search::OpenSearchResult).to receive(:build).and_call_original

      call
    end

    let(:search_result) do
      fixture_file = file_fixture('beta/search/goods_nomenclatures/single_hit.json')

      Hashie::TariffMash.new(JSON.parse(fixture_file.read))
    end

    let(:search_query_parser_service) { instance_double('Api::Beta::SearchQueryParserService', call: search_query_parser_result) }
    let(:search_query_parser_result) { build(:search_query_parser_result, :single_hit) }

    let(:expected_search_args) do
      {
        body: {
          query: {
            bool: {
              must: [
                {
                  multi_match: {
                    fields: [
                      'search_references^12',
                      'ancestor_1_description_indexed^10',
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
        index: 'tariff-goods_nomenclatures',
      }
    end

    let(:expected_serialized_result) do
      fixture_file = file_fixture('beta/search/goods_nomenclatures/serialized_result.json')

      JSON.parse(fixture_file.read)
    end

    it { expect(Api::Beta::SearchQueryParserService).to have_received(:new).with('ricotta') }
    it { expect(TradeTariffBackend.v2_search_client).to have_received(:search).with(expected_search_args) }
    it { expect(Beta::Search::OpenSearchResult).to have_received(:build).with(search_result, search_query_parser_result) }
    it { expect(call.to_json).to match_json_expression(expected_serialized_result) }
  end
end
