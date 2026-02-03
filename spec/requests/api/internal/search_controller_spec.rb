RSpec.describe Api::Internal::SearchController, :internal do
  before do
    allow(ExpandSearchQueryService).to receive(:call).and_wrap_original do |_method, query|
      ExpandSearchQueryService::Result.new(expanded_query: query, reason: nil)
    end
  end

  describe 'POST /search' do
    context 'when text query with results' do
      before do
        index = Search::GoodsNomenclatureIndex.new

        TradeTariffBackend.search_client.index_by_name(
          index.name,
          1,
          {
            goods_nomenclature_sid: 1,
            goods_nomenclature_item_id: '0100000000',
            producline_suffix: '80',
            goods_nomenclature_class: 'Chapter',
            description: 'horse',
            formatted_description: 'Horse',
            declarable: false,
            validity_start_date: Time.zone.today.iso8601,
          },
        )
        TradeTariffBackend.search_client.indices.refresh(index: '_all')
      end

      let(:pattern) do
        {
          'data' => [
            {
              'id' => be_present,
              'type' => 'chapter',
              'attributes' => {
                'goods_nomenclature_item_id' => '0100000000',
                'description' => String,
                'formatted_description' => String,
                'declarable' => be_in([true, false]),
                'score' => Numeric,
                'producline_suffix' => String,
                'goods_nomenclature_class' => 'Chapter',
              },
            },
          ],
        }
      end

      it 'returns goods_nomenclature results' do
        post api_search_path(format: :json), params: { q: 'horse', as_of: Time.zone.today.iso8601 }

        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_expression(pattern)
      end
    end

    context 'when exact match via search_reference suggestion' do
      before do
        heading = create(:heading, :with_description,
                         goods_nomenclature_item_id: '0101000000',
                         description: 'live horses')

        create(:search_suggestion, :search_reference,
               goods_nomenclature: heading,
               value: 'horse')
      end

      let(:pattern) do
        {
          'data' => [
            {
              'id' => be_present,
              'type' => 'heading',
              'attributes' => {
                'goods_nomenclature_item_id' => '0101000000',
                'description' => 'live horses',
                'formatted_description' => 'Live horses',
                'declarable' => be_in([true, false]),
                'score' => nil,
                'producline_suffix' => '80',
                'goods_nomenclature_class' => 'Heading',
              },
            },
          ],
        }
      end

      it 'returns the exact match with null score' do
        post api_search_path(format: :json), params: { q: 'horse', as_of: Time.zone.today.iso8601 }

        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_expression(pattern)
      end
    end

    context 'when exact match via padded numeric code' do
      before do
        chapter = create(:chapter, :with_description,
                         goods_nomenclature_item_id: '0100000000',
                         description: 'live animals')

        create(:search_suggestion, :goods_nomenclature,
               goods_nomenclature: chapter,
               value: '0100000000')
      end

      let(:pattern) do
        {
          'data' => [
            {
              'id' => be_present,
              'type' => 'chapter',
              'attributes' => {
                'goods_nomenclature_item_id' => '0100000000',
                'description' => 'live animals',
                'formatted_description' => 'Live animals',
                'declarable' => be_in([true, false]),
                'score' => nil,
                'producline_suffix' => '80',
                'goods_nomenclature_class' => 'Chapter',
              },
            },
          ],
        }
      end

      it 'returns the exact match with null score' do
        post api_search_path(format: :json), params: { q: '01', as_of: Time.zone.today.iso8601 }

        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_expression(pattern)
      end
    end

    context 'when empty query' do
      let(:pattern) do
        { 'data' => [] }
      end

      it 'returns an empty data array' do
        post api_search_path(format: :json)

        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_expression(pattern)
      end
    end

    context 'when rogue query' do
      let(:pattern) do
        { 'data' => [] }
      end

      it 'returns an empty data array' do
        post api_search_path(format: :json), params: { q: 'gif' }

        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_expression(pattern)
      end
    end

    context 'when ambiguous characters in query' do
      it 'handles the query without error' do
        post api_search_path(format: :json), params: { q: '! 0102' }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to have_key('data')
      end
    end
  end

  describe 'GET /search_suggestions' do
    context 'when query with results' do
      before do
        suggestion = create(:search_suggestion, :search_reference, value: 'same')
        index_model(suggestion)

        other = create(:search_suggestion, :search_reference, value: 'but different')
        index_model(other)

        TradeTariffBackend.search_client.indices.refresh(index: '_all')
      end

      let(:pattern) do
        {
          'data' => [
            {
              'id' => be_present,
              'type' => 'search_suggestion',
              'attributes' => {
                'value' => 'same',
                'score' => Numeric,
                'query' => 'same',
                'suggestion_type' => 'search_reference',
                'priority' => 1,
                'goods_nomenclature_class' => 'Heading',
              },
            },
          ],
        }
      end

      it 'returns JSONAPI array of suggestions' do
        get api_search_suggestions_path(format: :json), params: { q: 'same' }

        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_expression(pattern)
      end
    end

    context 'when empty query param' do
      it 'returns an empty data array' do
        get api_search_suggestions_path(format: :json), params: { q: '' }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq('data' => [])
      end
    end

    context 'when no query param at all' do
      it 'returns an empty data array' do
        get api_search_suggestions_path(format: :json)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq('data' => [])
      end
    end

    context 'when rogue query' do
      it 'returns an empty data array' do
        get api_search_suggestions_path(format: :json), params: { q: 'gif' }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq('data' => [])
      end
    end
  end
end
