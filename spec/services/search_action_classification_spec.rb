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

      it 'classifies a typed heading code without a suggestion as navigation' do
        heading
        search('0101')
        expect_action('navigation')
      end

      it 'classifies a typed commodity code without a suggestion as navigation' do
        create(:commodity, :with_description, goods_nomenclature_item_id: '0101210000')
        search('0101210000')
        expect_action('navigation')
      end

      it 'classifies a typed chapter code without a suggestion as navigation' do
        create(:chapter, :with_description, goods_nomenclature_item_id: '0100000000')
        search('01')
        expect_action('navigation')
      end

      it 'classifies an enabled chemical name suggestion as navigation' do
        allow(AdminConfiguration).to receive(:enabled?).with('suggest_chemical_names').and_return(true)
        create(:search_suggestion, :full_chemical_name, goods_nomenclature: heading, value: 'test chemical', declarable: true)
        search('test chemical')
        expect_action('navigation')
      end

      it 'classifies an enabled prefixed CAS suggestion as navigation' do
        allow(AdminConfiguration).to receive(:enabled?).with('suggest_chemical_cas').and_return(true)
        create(:search_suggestion, :full_chemical_cas, goods_nomenclature: heading, value: '10310-21-1', declarable: true)
        search('cas 10310-21-1')
        expect_action('navigation')
      end

      it 'keeps suggestions without a destination as search' do
        create(:search_suggestion, :search_reference, value: 'missing destination', declarable: true)
        search('missing destination')
        expect_action('search')
      end

      it 'keeps hidden direct code lookups as search' do
        create(:chapter, :with_description, :hidden, goods_nomenclature_item_id: '9900000000')
        search('9900000000')
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

      unless type == 'classic'
        it 'keeps disabled chemical suggestions as search' do
          allow(AdminConfiguration).to receive(:enabled?).with('suggest_chemical_cas').and_return(false)
          create(:search_suggestion, :full_chemical_cas, goods_nomenclature: heading, value: '10310-21-1', declarable: true)
          search('cas 10310-21-1')
          expect_action('search')
        end

        it 'does not classify a code rejected by a chapter exclusion as navigation' do
          heading
          allow(AdminConfiguration).to receive(:multi_options_values).and_call_original
          allow(AdminConfiguration).to receive(:multi_options_values).with('interactive_search_excluded_chapters').and_return(%w[01])
          search('0101')
          expect_action('search')
        end

        it 'does not classify a suggestion rejected by an intercept filter as navigation' do
          create(:description_intercept, term: 'horse', filter_prefixes: Sequel.pg_array(%w[9503], :text))
          create(:search_suggestion, :search_reference, goods_nomenclature: heading, value: 'horse', declarable: true)
          search('horse')
          expect_action('search')
        end
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
