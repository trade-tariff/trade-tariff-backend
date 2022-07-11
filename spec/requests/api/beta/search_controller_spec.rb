RSpec.describe Api::Beta::SearchController, type: :request do
  describe 'GET #index' do
    subject(:do_request) do
      # TODO: We're going to make the version just `beta` in a separate PR
      headers = { 'Accept' => 'application/vnd.uktt.vbeta' }

      get '/search', params: { q: 'ricotta' }, headers: headers

      response
    end

    before do
      allow(TradeTariffBackend.v2_search_client).to receive(:search).and_return(search_result)
      allow(Api::Beta::SearchQueryParserService).to receive(:new).and_return(search_query_parser_service)
    end

    let(:search_result) do
      test_filename = Rails.root.join(file_fixture_path, 'beta/search/goods_nomenclatures/single_hit.json')

      Hashie::TariffMash.new(JSON.parse(File.read(test_filename)))
    end

    let(:expected_serialized_result) do
      test_filename = Rails.root.join(file_fixture_path, 'beta/search/goods_nomenclatures/serialized_result.json')

      JSON.parse(File.read(test_filename))
    end

    let(:search_query_parser_service) { instance_double('Api::Beta::SearchQueryParserService', call: search_query_parser_result) }
    let(:search_query_parser_result) { build(:search_query_parser_result, :single_hit) }

    it { is_expected.to have_http_status(:ok) }
    it { expect(do_request.body).to match_json_expression(expected_serialized_result) }
  end
end
