RSpec.describe Api::Beta::SearchController, type: :request do
  describe 'GET #index' do
    subject(:do_request) do
      get '/api/beta/search?q=ricotta'

      response
    end

    before do
      allow(TradeTariffBackend.v2_search_client).to receive(:search).and_return(search_result)
      allow(Api::Beta::SearchQueryParserService).to receive(:new).and_return(search_query_parser_service)
    end

    let(:search_result) do
      fixture_file = file_fixture('beta/search/goods_nomenclatures/single_hit.json')

      Hashie::TariffMash.new(JSON.parse(fixture_file.read))
    end

    let(:expected_serialized_result) do
      fixture_file = file_fixture('beta/search/goods_nomenclatures/serialized_result.json')
      JSON.parse(fixture_file.read)
    end

    let(:search_query_parser_service) { instance_double('Api::Beta::SearchQueryParserService', call: search_query_parser_result) }
    let(:search_query_parser_result) { build(:search_query_parser_result, :single_hit) }

    it { is_expected.to have_http_status(:ok) }
    it { expect(do_request.body).to match_json_expression(expected_serialized_result) }
  end
end
