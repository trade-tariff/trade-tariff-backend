RSpec.describe 'Classic V2 HS code search', type: :request do
  def submit_search(method, query)
    options = method == :post ? { as: :json } : {}
    public_send(method, '/uk/api/search', params: { q: query }, headers: request_headers, **options)
  end

  before do
    allow(Search::Instrumentation).to receive(:fuzzy_results_returned).and_call_original
    allow(Search::Instrumentation).to receive(:search_action_classified).and_call_original
  end

  %i[get post].each do |method|
    context "with #{method.upcase}" do
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

          submit_search(method, plain_code)
          control = response.parsed_body
          expect(control.dig('data', 'attributes', 'type')).to eq('exact_match')

          submit_search(method, term)

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to eq(control)
          expect(Search::Instrumentation).not_to have_received(:fuzzy_results_returned)
          expect(Search::Instrumentation).to have_received(:search_action_classified)
            .with(hash_including(search_action: 'navigation')).twice
        end
      end

      it 'keeps historic lookup for HS:8419500090' do
        create(:commodity, :with_description, :non_current, goods_nomenclature_item_id: '8419500090')

        submit_search(method, '8419500090')
        control = response.parsed_body
        expect(control.dig('data', 'attributes', 'entry')).to eq('endpoint' => 'commodities', 'id' => '8419500090')

        submit_search(method, 'HS:8419500090')

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq(control)
      end

      %w[940340 9403400090].each do |code|
        it "keeps fuzzy search for missing HS:#{code}" do
          submit_search(method, code)
          control = response.parsed_body

          submit_search(method, "HS:#{code}")

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to eq(control)
          expect(response.parsed_body.dig('data', 'attributes', 'type')).not_to eq('exact_match')
          expect(Search::Instrumentation).to have_received(:fuzzy_results_returned).with(hash_including(query: code)).twice
          expect(Search::Instrumentation).to have_received(:search_action_classified)
            .with(hash_including(search_action: 'search')).twice
        end
      end
    end
  end
end
