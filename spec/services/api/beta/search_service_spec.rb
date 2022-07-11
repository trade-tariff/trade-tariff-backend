RSpec.describe Api::Beta::SearchService do
  describe '#call' do
    subject(:call) { described_class.new('ricotta').call }

    before do
      allow(TradeTariffBackend.v2_search_client).to receive(:search).and_return(search_result)
      allow(Api::Beta::SearchQueryParserService).to receive(:new).and_return(search_query_parser_service)
      allow(Beta::Search::SearchResult).to receive(:build).and_call_original

      call
    end

    let(:search_result) do
      test_filename = Rails.root.join(file_fixture_path, 'beta/search/goods_nomenclatures/single_hit.json')

      Hashie::TariffMash.new(JSON.parse(File.read(test_filename)))
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
                      'chapter_description^10',
                      'heading_description^8',
                      'description.exact^6',
                      'description_indexed^6',
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
      test_filename = Rails.root.join(file_fixture_path, 'beta/search/goods_nomenclatures/serialized_result.json')

      JSON.parse(File.read(test_filename))
    end

    it { expect(Api::Beta::SearchQueryParserService).to have_received(:new).with('ricotta') }
    it { expect(TradeTariffBackend.v2_search_client).to have_received(:search).with(expected_search_args) }
    it { expect(Beta::Search::SearchResult).to have_received(:build).with(search_result, search_query_parser_result) }
    it { expect(call.to_json).to match_json_expression(expected_serialized_result) }
  end
end
