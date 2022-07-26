RSpec.describe Api::Beta::SearchController, type: :request do
  describe 'GET #index' do
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

    shared_examples_for 'a working search request' do |prefix|
      subject(:do_request) do
        get "#{prefix}/api/beta/search?q=ricotta"

        response
      end

      it { is_expected.to have_http_status(:ok) }
      it { expect(do_request.body).to match_json_expression(expected_serialized_result) }

      context 'when the search result tells us to redirect and the search query is a heading' do
        let(:search_result) { build(:search_result, :redirect, :heading) }

        let(:pattern) do
          {
            meta: {
              redirect: true,
              redirect_to: 'http://localhost:3001/headings/0101',
            },
          }.ignore_extra_keys!
        end

        before do
          allow(Beta::Search::OpenSearchResult).to receive(:build).and_return(search_result)
        end

        it { expect(do_request.body).to match_json_expression(pattern) }
      end

      context 'when the search result tells us to redirect and the search query is a chapter' do
        let(:search_result) { build(:search_result, :redirect, :chapter) }

        let(:pattern) do
          {
            meta: {
              redirect: true,
              redirect_to: 'http://localhost:3001/chapters/01',
            },
          }.ignore_extra_keys!
        end

        before do
          allow(Beta::Search::OpenSearchResult).to receive(:build).and_return(search_result)
        end

        it { expect(do_request.body).to match_json_expression(pattern) }
      end

      context 'when the search result tells us to redirect and the search query is a commodity' do
        let(:search_result) { build(:search_result, :redirect, :commodity) }

        let(:pattern) do
          {
            meta: {
              redirect: true,
              redirect_to: 'http://localhost:3001/commodities/0101210000',
            },
          }.ignore_extra_keys!
        end

        before do
          allow(Beta::Search::OpenSearchResult).to receive(:build).and_return(search_result)
        end

        it { expect(do_request.body).to match_json_expression(pattern) }
      end

      context 'when the search result tells us to redirect and the search query is a partial commodity code' do
        let(:search_result) { build(:search_result, :redirect, :partial_goods_nomenclature) }

        let(:pattern) do
          {
            meta: {
              redirect: true,
              redirect_to: 'http://localhost:3001/headings/0101',
            },
          }.ignore_extra_keys!
        end

        before do
          allow(Beta::Search::OpenSearchResult).to receive(:build).and_return(search_result)
        end

        it { expect(do_request.body).to match_json_expression(pattern) }
      end
    end

    it_behaves_like 'a working search request', '/xi'
    it_behaves_like 'a working search request', '/uk'
    it_behaves_like 'a working search request', ''
  end
end
