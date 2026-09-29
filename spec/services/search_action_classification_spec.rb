RSpec.describe 'Search action classification' do
  let(:events) { [] }
  let(:request_id) { SecureRandom.uuid }
  let(:heading) { create(:heading, :with_description, goods_nomenclature_item_id: '0101000000', description: 'Live horses') }

  around do |example|
    subscriber = ActiveSupport::Notifications.subscribe('search_action_classified.search') { |event| events << event.payload }
    TradeTariffRequest.set(request_id:, request_source: 'frontend', search_failures: []) { example.run }
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  before do
    allow(TradeTariffBackend.search_client).to receive(:search).and_return('hits' => { 'hits' => [] })
    allow(AdminConfiguration).to receive(:option_value).and_call_original
    allow(AdminConfiguration).to receive(:option_value).with('retrieval_method').and_return('opensearch')
    allow(AdminConfiguration).to receive(:enabled?).and_call_original
    allow(AdminConfiguration).to receive(:enabled?).with('expand_search_when_needed_enabled').and_return(false)
    allow(ExpandSearchQueryService).to receive(:call) { |query, **| ExpandSearchQueryService::Result.new(expanded_query: query, reason: nil) }
  end

  %w[classic internal interactive].each do |type|
    context "with #{type} search" do
      let(:search_type) { type }

      def search(query)
        if search_type == 'classic'
          SearchService.new(Api::V2::SearchSerializationService.new, q: query).to_json
        else
          Api::Internal::SearchService.new(q: query, request_id:, search_type:).call
        end
      end

      def expect_action(action)
        expect(events).to contain_exactly(hash_including(request_id:, request_source: 'frontend', search_type:, search_action: action, search_degraded: false))
      end

      it 'classifies a typed suggestion' do
        create(:search_suggestion, :search_reference, goods_nomenclature: heading, value: 'horse', declarable: true)
        search('horse')
        expect_action('navigation')
      end

      it 'keeps plural suggestion matching' do
        create(:search_suggestion, :search_reference, goods_nomenclature: heading, value: 'horse', declarable: true)
        search('horses')
        expect_action('navigation')
      end

      it 'classifies padded code suggestions' do
        create(:search_suggestion, :goods_nomenclature, goods_nomenclature: heading, value: '0101000000', declarable: true)
        search('0101')
        expect_action('navigation')
      end

      it 'distinguishes direct code lookups' do
        heading
        search('0101')
        expect_action('search')
      end

      it 'classifies a query without a match' do
        search('unmatched goods')
        expect_action('search')
      end

      it 'classifies an unmatched code' do
        search('9999999999')
        expect_action('search')
      end

      it 'keeps rejected suggestions as search' do
        hidden = create(:chapter, :with_description, :hidden, goods_nomenclature_item_id: '9900000000', description: 'Hidden goods')
        create(:search_suggestion, :goods_nomenclature, goods_nomenclature: hidden, value: '9900000000', declarable: true)
        search('9900000000')
        expect_action('search')
      end

      it 'classifies before retrieval failure' do
        operation = search_type == 'classic' ? :msearch : :search
        allow(TradeTariffBackend.search_client).to receive(operation).and_raise(StandardError, 'retrieval failed')
        expect { search('unmatched goods') }.to raise_error(StandardError, 'retrieval failed')
        expect_action('search')
      end
    end
  end
end
