RSpec.describe 'Internal HS code search', :internal, type: :request do
  before do
    allow(AdminConfiguration).to receive(:option_value).and_call_original
    allow(AdminConfiguration).to receive(:option_value).with('retrieval_method').and_return('hybrid')
    allow(AdminConfiguration).to receive(:enabled?).and_call_original
    allow(AdminConfiguration).to receive(:enabled?).with('expand_search_enabled').and_return(false)
    allow(HybridRetrievalService).to receive(:call) do |query:, **|
      HybridRetrievalService::Result.new(results: [], expanded_query: query, source_results: [])
    end
    allow(InteractiveSearchService).to receive(:call)
    allow(Search::Instrumentation).to receive(:search_action_classified)
  end

  [false, true].each do |skip_question|
    context "with skip_question #{skip_question}" do
      [
        ['hs 8716109800', '8716109800', '8716109800', :commodity],
        ['HS 8708.50.20', '8708.50.20', '8708502000', :subheading],
        ['HS9504400000', '9504400000', '9504400000', :commodity],
      ].each do |term, plain_code, code, factory|
        it "navigates #{term} like its plain code" do
          goods = create(factory, :with_description, goods_nomenclature_item_id: code)
          TimeMachine.now do
            create(:search_suggestion, :goods_nomenclature, goods_nomenclature: goods, value: code)
          end

          post api_search_path(format: :json), params: { q: plain_code, skip_question: }, as: :json
          control = response.parsed_body
          expect(control.dig('data', 0, 'attributes', 'goods_nomenclature_item_id')).to eq(code)

          post api_search_path(format: :json), params: { q: term, skip_question: }, as: :json

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to eq(control)
          expect(HybridRetrievalService).not_to have_received(:call)
          expect(InteractiveSearchService).not_to have_received(:call)
          expect(Search::Instrumentation).to have_received(:search_action_classified)
            .with(hash_including(search_action: 'navigation')).twice
        end
      end

      it 'keeps historic lookup for HS:8419500090' do
        create(:commodity, :with_description, :non_current, goods_nomenclature_item_id: '8419500090')

        post api_search_path(format: :json), params: { q: '8419500090', skip_question: }, as: :json
        control = response.parsed_body
        expect(control.dig('data', 0, 'attributes', 'goods_nomenclature_item_id')).to eq('8419500090')

        post api_search_path(format: :json), params: { q: 'HS:8419500090', skip_question: }, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq(control)
        expect(HybridRetrievalService).not_to have_received(:call)
      end

      %w[940340 9403400090].each do |code|
        it "keeps retrieval for missing HS:#{code}" do
          post api_search_path(format: :json), params: { q: code, skip_question: }, as: :json
          control = response.parsed_body

          post api_search_path(format: :json), params: { q: "HS:#{code}", skip_question: }, as: :json

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to eq(control)
          expect(response.parsed_body['data']).to be_empty
          expect(HybridRetrievalService).to have_received(:call).with(hash_including(query: code)).twice
          expect(Search::Instrumentation).to have_received(:search_action_classified)
            .with(hash_including(search_action: 'search')).twice
        end
      end
    end
  end
end
