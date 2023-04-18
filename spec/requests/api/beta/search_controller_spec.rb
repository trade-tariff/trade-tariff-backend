RSpec.describe Api::Beta::SearchController, type: :request do
  describe 'GET #index' do
    context 'when doing a full search' do
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
          get "#{prefix}/api/beta/search?q=ricotta&filter[cheese_type]=fresh"

          response
        end

        it { is_expected.to have_http_status(:ok) }
        it { expect(do_request.body).to match_json_expression(expected_serialized_result) }
      end

      it_behaves_like 'a working search request', '/xi'
      it_behaves_like 'a working search request', '/uk'
      it_behaves_like 'a working search request', ''
    end

    context 'when redirecting because of a search reference' do
      subject(:do_request) do
        get '/api/beta/search?q=raw'

        response
      end

      let(:direct_hit) { JSON.parse(do_request.body).dig('data', 'relationships', 'direct_hit') }

      let(:expected_direct_hit) do
        {
          'data' => {
            'id' => '0101000000-80',
            'type' => 'heading',
          },
        }
      end

      before do
        create(
          :search_suggestion,
          :search_reference,
          goods_nomenclature: create(:heading, goods_nomenclature_item_id: '0101000000'),
          value: 'raw',
        )
      end

      it { expect(direct_hit).to eq(expected_direct_hit) }
    end
  end
end
