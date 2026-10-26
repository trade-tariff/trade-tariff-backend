RSpec.describe ExpandSearchQueryService do
  subject(:result) { described_class.call(query, request_id: 'request-123') }

  after { TradeTariffRequest.search_failures = nil }

  let(:ai_response) do
    {
      'expanded_query' => 'Portable automatic data-processing machines',
      'reason' => "The term 'laptop' is colloquial; tariff uses formal terminology.",
    }
  end

  let(:default_context) { 'Please rephrase and expand the following search query: %{search_query}' }

  before do
    allow(OpenaiClient).to receive(:call).and_return(ai_response)
    create(:admin_configuration, name: 'expand_query_context', value: default_context, area: 'classification')
  end

  describe '.call' do
    context 'when the query is a text search term' do
      let(:query) { 'laptop' }

      it 'appends the AI rewrite after the unchanged original query' do
        expect(result.expanded_query).to eq('laptop Portable automatic data-processing machines')
      end

      it 'returns the reason for expansion' do
        expect(result.reason).to eq("The term 'laptop' is colloquial; tariff uses formal terminology.")
      end

      it 'calls the AI client with the expansion context' do
        result

        expect(OpenaiClient).to have_received(:call).with(
          a_string_including('laptop'),
          model: 'gpt-4.1-mini-2025-04-14',
          reasoning_effort: nil,
          event_kind: 'search_query_expansion',
          timeout: 5.0,
        )
      end

      it 'correlates the model call with the search request' do
        allow(Search::Instrumentation).to receive(:api_call).and_call_original

        result

        expect(Search::Instrumentation).to have_received(:api_call).with(
          hash_including(request_id: 'request-123', operation: 'search_query_expansion'),
        )
      end
    end

    context 'when the query is a numeric commodity code' do
      let(:query) { '8471301000' }

      it 'returns the original query unchanged' do
        expect(result.expanded_query).to eq('8471301000')
      end

      it 'returns nil reason' do
        expect(result.reason).to be_nil
      end

      it 'does not call the AI client' do
        result

        expect(OpenaiClient).not_to have_received(:call)
      end

      it 'does not record a failure for a stage that was not needed' do
        result

        expect(TradeTariffRequest.search_failures).to be_nil
      end
    end

    context 'when the query is a short numeric code' do
      let(:query) { '8471' }

      it 'returns the original query unchanged' do
        expect(result.expanded_query).to eq('8471')
      end

      it 'does not call the AI client' do
        result

        expect(OpenaiClient).not_to have_received(:call)
      end
    end

    context 'when the query is blank' do
      let(:query) { '' }

      it 'returns empty string unchanged' do
        expect(result.expanded_query).to eq('')
      end

      it 'does not call the AI client' do
        result

        expect(OpenaiClient).not_to have_received(:call)
      end
    end

    context 'when the query is nil' do
      let(:query) { nil }

      it 'returns empty string' do
        expect(result.expanded_query).to eq('')
      end

      it 'does not call the AI client' do
        result

        expect(OpenaiClient).not_to have_received(:call)
      end
    end

    context 'when the AI returns an unparseable response' do
      let(:query) { 'laptop' }
      let(:ai_response) { 'some raw text' }

      it 'falls back to the original query' do
        expect(result.expanded_query).to eq('laptop')
      end

      it 'returns nil reason' do
        expect(result.reason).to be_nil
      end

      it 'records the expansion failure' do
        result

        expect(TradeTariffRequest.search_failures).to eq(%w[query_expansion_failed])
      end
    end

    context 'when the AI returns an empty expanded_query' do
      let(:query) { 'laptop' }
      let(:ai_response) { { 'expanded_query' => '', 'reason' => 'empty' } }

      it 'falls back to the original query' do
        expect(result.expanded_query).to eq('laptop')
      end

      it 'records the malformed provider response as an expansion failure' do
        result

        expect(TradeTariffRequest.search_failures).to eq(%w[query_expansion_failed])
      end
    end

    context 'when the AI validly returns the original query' do
      let(:query) { 'laptop' }
      let(:ai_response) { { 'expanded_query' => 'laptop', 'reason' => 'already tariff-ready' } }

      it 'does not infer a failure from the unchanged value' do
        expect(result.expanded_query).to eq('laptop')
        expect(TradeTariffRequest.search_failures).to be_nil
      end
    end

    context 'when the AI returns added terms' do
      let(:query) { 'laptop' }
      let(:ai_response) do
        { 'added_terms' => ['portable computers', 'notebook computers'], 'reason' => 'The term is colloquial.' }
      end

      it 'appends each term after the unchanged original query' do
        expect(result.expanded_query).to eq('laptop portable computers notebook computers')
      end

      it 'returns the reason for expansion' do
        expect(result.reason).to eq('The term is colloquial.')
      end

      it 'does not record a failure' do
        expect(TradeTariffRequest.search_failures).to be_nil
      end
    end

    context 'when the AI returns no added terms' do
      let(:query) { 'laptop' }
      let(:ai_response) { { 'added_terms' => [], 'reason' => 'already tariff-ready' } }

      it 'returns the original query unchanged' do
        expect(result.expanded_query).to eq('laptop')
      end

      it 'does not record a failure' do
        expect(TradeTariffRequest.search_failures).to be_nil
      end
    end

    context 'when the AI returns more than five added terms' do
      let(:query) { 'laptop' }
      let(:ai_response) do
        {
          'added_terms' => [
            'portable computers',
            'notebook computers',
            'mobile computers',
            'tablet computers',
            'handheld computers',
            'desktop computers',
            'server computers',
          ],
          'reason' => 'The term is colloquial.',
        }
      end

      it 'appends at most five added phrases' do
        expect(result.expanded_query)
          .to eq('laptop portable computers notebook computers mobile computers tablet computers handheld computers')
      end
    end

    context 'when an added phrase repeats the original wording' do
      let(:query) { 'laptop' }
      let(:ai_response) { { 'added_terms' => ['laptop', 'portable computers'], 'reason' => 'The term is colloquial.' } }

      it 'drops the phrase that adds nothing' do
        expect(result.expanded_query).to eq('laptop portable computers')
      end
    end

    context 'when an added phrase repeats the original wording with punctuation' do
      let(:query) { 'laptop,' }
      let(:ai_response) { { 'added_terms' => %w[laptop], 'reason' => 'The term is colloquial.' } }

      it 'drops the phrase that adds no new word' do
        expect(result.expanded_query).to eq('laptop,')
      end
    end

    context 'when added phrases differ only by case' do
      let(:query) { 'laptop' }
      let(:ai_response) { { 'added_terms' => ['portable computers', 'Portable Computers'], 'reason' => 'x' } }

      it 'keeps one copy of the phrase' do
        expect(result.expanded_query).to eq('laptop portable computers')
      end
    end

    context 'when an added phrase converts units' do
      let(:query) { '2kW heater' }
      let(:ai_response) { { 'added_terms' => ['2000 watt heater'], 'reason' => 'Convert kilowatts to watts.' } }

      it 'keeps the numeric equivalent' do
        expect(result.expanded_query).to eq('2kW heater 2000 watt heater')
      end
    end

    context 'when an added phrase names a product standard' do
      let(:query) { 'stainless steel' }
      let(:ai_response) { { 'added_terms' => ['EN 10088 steel'], 'reason' => 'Related steel standard.' } }

      it 'does not treat an identifier as a tariff code' do
        expect(result.expanded_query).to eq('stainless steel EN 10088 steel')
      end
    end

    context 'when a legacy rewrite converts units' do
      let(:query) { '2kW heater' }
      let(:ai_response) { { 'expanded_query' => '2000 watt heater', 'reason' => 'Convert kilowatts to watts.' } }

      it 'keeps the original wording and the conversion' do
        expect(result.expanded_query).to eq('2kW heater 2000 watt heater')
      end
    end

    context 'when an added phrase invents a commodity code' do
      let(:query) { 'laptop' }
      let(:ai_response) do
        { 'added_terms' => ['portable computers', 'heading 8471301000'], 'reason' => 'The term is colloquial.' }
      end

      it 'drops the phrase with the invented code' do
        expect(result.expanded_query).to eq('laptop portable computers')
      end
    end

    context 'when an added phrase explicitly names an HS code' do
      let(:query) { 'laptop' }
      let(:ai_response) { { 'added_terms' => ['portable computers', 'HS code: 8471301000'], 'reason' => 'Tariff terminology.' } }

      it 'drops the new code reference' do
        expect(result.expanded_query).to eq('laptop portable computers')
      end
    end

    ['8471.30.10.00', '8471 30 10 00'].each do |formatted_code|
      context "when an addition specifies #{formatted_code} below the supplied heading" do
        let(:query) { '8471 laptop' }
        let(:ai_response) do
          { 'added_terms' => ['portable computers', "HS code #{formatted_code}"], 'reason' => 'Tariff terminology.' }
        end

        it 'rejects the more-specific code' do
          expect(result.expanded_query).to eq('8471 laptop portable computers')
        end
      end
    end

    [
      ['8471301000', '8471.30.10.00'],
      ['8471.30.10.00', '8471301000'],
      ['8471 30 10 00', '8471.30.10.00'],
    ].each do |supplied_code, expanded_code|
      context "when the supplied code #{supplied_code} is formatted as #{expanded_code}" do
        let(:query) { "#{supplied_code} laptop" }
        let(:ai_response) do
          { 'added_terms' => ["HS code #{expanded_code}"], 'reason' => 'Tariff terminology.' }
        end

        it 'keeps the supplied complete code' do
          expect(result.expanded_query).to eq("#{query} HS code #{expanded_code}")
        end
      end
    end

    [
      ['8471 30 2 laptops', '8471.30'],
      ['8471.30 2 laptops', '847130'],
      ['8471 30 10 00 2 laptops', '8471301000'],
    ].each do |original_query, supplied_code|
      context "when #{original_query.inspect} includes a grouped code before a quantity" do
        let(:query) { original_query }
        let(:ai_response) { { 'added_terms' => ["HS code #{supplied_code}"], 'reason' => 'Repeat the supplied code.' } }

        it 'keeps the longest valid code prefix' do
          expect(result.expanded_query).to eq("#{query} HS code #{supplied_code}")
        end
      end
    end

    context 'when a quantity interrupts code groups' do
      let(:query) { '8471 30 2 10 laptops' }
      let(:ai_response) { { 'added_terms' => ['HS code 84713010'], 'reason' => 'Tariff terminology.' } }

      it 'does not skip the quantity to build a code' do
        expect(result.expanded_query).to eq(query)
      end
    end

    context 'when a code-like addition is not labelled as a tariff reference' do
      let(:query) { 'laptops' }
      let(:ai_response) { { 'added_terms' => ['8471 30 10 00 laptops'], 'reason' => 'Search terminology.' } }

      it 'keeps the deliberate numeric recall trade-off' do
        expect(result.expanded_query).to eq('laptops 8471 30 10 00 laptops')
      end
    end

    context 'when a supplied heading is next to a quantity' do
      let(:query) { '8471 2 laptops' }
      let(:ai_response) { { 'added_terms' => ['heading 8471'], 'reason' => 'Repeat the supplied heading.' } }

      it 'keeps the explicitly supplied heading' do
        expect(result.expanded_query).to eq('8471 2 laptops heading 8471')
      end
    end

    context 'when an addition combines a heading and a quantity into a code' do
      let(:query) { '8471 2 laptops' }
      let(:ai_response) { { 'added_terms' => ['HS code 84712'], 'reason' => 'Tariff terminology.' } }

      it 'rejects the combined number' do
        expect(result.expanded_query).to eq(query)
      end
    end

    context 'when adjacent numbers have invalid code grouping' do
      let(:query) { '2024 1000 printers' }
      let(:ai_response) { { 'added_terms' => ['HS code 20241000'], 'reason' => 'Tariff terminology.' } }

      it 'does not turn separate numbers into a code' do
        expect(result.expanded_query).to eq(query)
      end
    end

    context 'when an added phrase repeats a number from the original query' do
      let(:query) { '8471 laptop' }
      let(:ai_response) { { 'added_terms' => ['portable computers', 'heading 8471'], 'reason' => 'The term is colloquial.' } }

      it 'keeps the phrase' do
        expect(result.expanded_query).to eq('8471 laptop portable computers heading 8471')
      end
    end

    context 'when a legacy rewrite keeps the original query as a prefix' do
      let(:query) { 'laptop' }
      let(:ai_response) { { 'expanded_query' => 'laptop portable computers', 'reason' => 'The term is colloquial.' } }

      it 'does not duplicate the original wording' do
        expect(result.expanded_query).to eq('laptop portable computers')
      end
    end

    context 'when a legacy rewrite is a comma-separated list' do
      let(:query) { 'laptop' }
      let(:ai_response) do
        {
          'expanded_query' => 'laptop, portable computers, notebooks, netbooks, tablets, smartphones, chromebooks, ultrabooks',
          'reason' => 'The term is colloquial.',
        }
      end

      it 'keeps the original query and appends at most five comma-separated phrases' do
        expect(result.expanded_query).to eq('laptop portable computers notebooks netbooks tablets smartphones')
      end
    end

    context 'when an added term is not a string' do
      let(:query) { 'laptop' }
      let(:ai_response) { { 'added_terms' => [123, 'portable computers'], 'reason' => 'The term is colloquial.' } }

      it 'keeps only the string entries' do
        expect(result.expanded_query).to eq('laptop portable computers')
      end
    end

    [123, true, %w[laptop], { 'query' => 'laptop' }].each do |malformed_query|
      context "when expanded_query is #{malformed_query.inspect}" do
        let(:query) { 'laptop' }
        let(:ai_response) { { 'expanded_query' => malformed_query } }

        it 'returns the original query', :aggregate_failures do
          expect(result.expanded_query).to eq('laptop')
          expect(TradeTariffRequest.search_failures).to eq(%w[query_expansion_failed])
        end
      end
    end

    context 'when the AI returns nil' do
      let(:query) { 'laptop' }
      let(:ai_response) { nil }

      it 'falls back to the original query' do
        expect(result.expanded_query).to eq('laptop')
      end

      it 'records the malformed provider response as an expansion failure' do
        result

        expect(TradeTariffRequest.search_failures).to eq(%w[query_expansion_failed])
      end
    end

    context 'when the AI client raises an error' do
      let(:query) { 'laptop' }

      before do
        allow(OpenaiClient).to receive(:call).and_raise(Faraday::TimeoutError)
        TradeTariffRequest.request_id = 'req-1'
      end

      it 'falls back to the original query' do
        expect(result.expanded_query).to eq('laptop')
      end

      it 'returns nil reason' do
        expect(result.reason).to be_nil
      end

      it 'records the expansion failure' do
        result

        expect(TradeTariffRequest.search_failures).to eq(%w[query_expansion_failed])
      end

      it 'emits a search_stage_failed event' do
        allow(Search::Instrumentation).to receive(:search_stage_failed)

        result

        expect(Search::Instrumentation).to have_received(:search_stage_failed).with(
          request_id: 'request-123',
          error_type: 'Faraday::TimeoutError',
          error_message: anything,
          search_type: 'interactive',
          failure_code: 'query_expansion_failed',
          operation: 'search_query_expansion',
        )
      end
    end

    context 'when the expansion deadline expires' do
      let(:query) { 'laptop' }
      let(:deadline_error) do
        OpenaiClient::DeadlineExceeded.new(timeout_seconds: 5, elapsed_seconds: 5.01)
      end

      before do
        allow(OpenaiClient).to receive(:call).and_raise(deadline_error)
        allow(Search::Instrumentation).to receive(:query_expansion_timed_out)
        allow(Search::Instrumentation).to receive(:search_failed)
      end

      it 'falls back to the original query' do
        expect(result.expanded_query).to eq('laptop')
      end

      it 'records the expansion failure' do
        result

        expect(TradeTariffRequest.search_failures).to eq(%w[query_expansion_failed])
      end

      it 'emits timeout telemetry' do
        result

        expect(Search::Instrumentation).to have_received(:query_expansion_timed_out).with(
          request_id: 'request-123',
          timeout_ms: 5000,
          elapsed_ms: 5010.0,
          model: 'gpt-4.1-mini-2025-04-14',
          fallback_outcome: 'original_query',
        )
      end

      it 'does not emit search_failed' do
        result

        expect(Search::Instrumentation).not_to have_received(:search_failed)
      end
    end
  end

  describe 'AdminConfiguration integration' do
    let(:query) { 'laptop' }

    context 'when expand_model config exists' do
      before do
        create(:admin_configuration, :nested_options,
               name: 'expand_model',
               area: 'classification',
               value: {
                 'selected' => 'gpt-4.1-mini-2025-04-14',
                 'sub_values' => {},
                 'options' => [
                   { 'key' => 'gpt-4.1-mini-2025-04-14', 'label' => 'GPT-4.1 Mini', 'sub_options' => {} },
                 ],
               })
      end

      it 'uses the configured model' do
        result

        expect(OpenaiClient).to have_received(:call).with(
          anything,
          model: 'gpt-4.1-mini-2025-04-14',
          reasoning_effort: nil,
          event_kind: 'search_query_expansion',
          timeout: 5.0,
        )
      end
    end

    context 'when expand_query_context config exists' do
      let(:custom_context) { 'Custom prompt for: %{search_query}' }

      before do
        AdminConfiguration.where(name: 'expand_query_context').first.update(value: Sequel.pg_jsonb_wrap(custom_context))
      end

      it 'uses the configured context with the query interpolated' do
        result

        expect(OpenaiClient).to have_received(:call).with(
          'Custom prompt for: laptop',
          model: 'gpt-4.1-mini-2025-04-14',
          reasoning_effort: nil,
          event_kind: 'search_query_expansion',
          timeout: 5.0,
        )
      end
    end
  end

  describe 'caching' do
    let(:query) { 'laptop' }
    let(:memory_store) { ActiveSupport::Cache::MemoryStore.new }

    before do
      allow(Rails).to receive(:cache).and_return(memory_store)
    end

    it 'caches successful expansions' do
      described_class.call(query)
      described_class.call(query)

      expect(OpenaiClient).to have_received(:call).once
    end

    it 'returns cached result on subsequent calls' do
      first_result = described_class.call(query)
      second_result = described_class.call(query)

      expect(second_result.expanded_query).to eq(first_result.expanded_query)
      expect(second_result.reason).to eq(first_result.reason)
    end

    it 'replaces malformed cached data', :aggregate_failures do
      described_class.call(query)
      allow(memory_store).to receive(:read).and_wrap_original do |original, key, **options|
        original.call(key, **options).merge(expanded_query: 123)
      end

      expect(described_class.call(query).expanded_query).to eq('laptop Portable automatic data-processing machines')
      expect(TradeTariffRequest.search_failures).to eq(%w[query_expansion_failed])
      expect(OpenaiClient).to have_received(:call).twice
    end

    it 'does not cache malformed expansions' do
      allow(OpenaiClient).to receive(:call).and_return({ 'expanded_query' => 123 }, ai_response)
      described_class.call(query)

      expect(described_class.call(query).expanded_query).to eq('laptop Portable automatic data-processing machines')
    end

    it 'caches the rebuilt expanded query' do
      allow(memory_store).to receive(:write).and_wrap_original do |original, key, value, **options|
        original.call(key, value, **options)
        value
      end

      described_class.call(query)

      expect(memory_store).to have_received(:write)
        .with(anything, hash_including(expanded_query: 'laptop Portable automatic data-processing machines'), anything)
    end

    it 'rebuilds a cached rewrite that replaced the original query' do
      cache_key = nil
      allow(memory_store).to receive(:write).and_wrap_original do |original, key, value, **options|
        cache_key = key
        original.call(key, value, **options)
      end
      described_class.call(query)

      memory_store.write(
        cache_key,
        { expanded_query: 'Portable automatic data-processing machines', reason: 'legacy rewrite' },
        expires_in: described_class::CACHE_TTL,
      )
      allow(OpenaiClient).to receive(:call).and_return({ 'added_terms' => %w[ignored], 'reason' => 'fresh' })

      expect(described_class.call(query).expanded_query).to eq('laptop Portable automatic data-processing machines')
      expect(OpenaiClient).to have_received(:call).once
    end

    context 'when the old guard cached a rejected conversion' do
      let(:query) { '2kW heater' }
      let(:ai_response) { { 'added_terms' => ['2000 watt heater'], 'reason' => 'Convert kilowatts to watts.' } }

      it 'uses a new cache namespace' do
        digest = Digest::MD5.hexdigest(default_context)[0, 8]
        legacy_key = "expand_search_query/gpt-4.1-mini-2025-04-14/#{digest}/#{query.downcase}"
        memory_store.write(legacy_key, { expanded_query: query, reason: nil })

        fresh = described_class.call(query)
        cached = described_class.call(query)

        expect(fresh.expanded_query).to eq('2kW heater 2000 watt heater')
        expect(cached).to eq(fresh)
        expect(OpenaiClient).to have_received(:call).once
      end
    end

    context 'when v2 cached a rejected grouped code before a quantity' do
      let(:query) { '8471 30 2 laptops' }
      let(:ai_response) { { 'added_terms' => ['HS code 8471.30'], 'reason' => 'Repeat the supplied code.' } }

      it 'fetches and caches the preserved code in the new namespace', :aggregate_failures do
        digest = Digest::MD5.hexdigest(default_context)[0, 8]
        key_suffix = "gpt-4.1-mini-2025-04-14/#{digest}/#{query.downcase}"
        memory_store.write("expand_search_query/v2/#{key_suffix}", { expanded_query: query, reason: nil })

        fresh = described_class.call(query)
        cached = described_class.call(query)

        expect(fresh.expanded_query).to eq('8471 30 2 laptops HS code 8471.30')
        expect(cached).to eq(fresh)
        expect(memory_store.read("expand_search_query/v3/#{key_suffix}"))
          .to include(expanded_query: fresh.expanded_query)
        expect(OpenaiClient).to have_received(:call).once
      end
    end

    it 'treats queries case-insensitively' do
      described_class.call('Laptop')
      described_class.call('laptop')
      described_class.call('LAPTOP')

      expect(OpenaiClient).to have_received(:call).once
    end

    context 'when the AI returns an error' do
      let(:ai_response) { nil }

      it 'does not cache the failure' do
        described_class.call(query)

        allow(OpenaiClient).to receive(:call).and_return(
          'expanded_query' => 'Portable computers',
          'reason' => 'test',
        )

        described_class.call(query)

        expect(OpenaiClient).to have_received(:call).twice
      end
    end

    context 'when the AI raises an exception' do
      before do
        allow(OpenaiClient).to receive(:call).and_raise(Faraday::TimeoutError)
      end

      it 'does not cache the failure' do
        described_class.call(query)

        allow(OpenaiClient).to receive(:call).and_return(ai_response)

        described_class.call(query)

        expect(OpenaiClient).to have_received(:call).twice
      end
    end

    context 'when the expansion deadline expires' do
      before do
        allow(OpenaiClient).to receive(:call).and_raise(
          OpenaiClient::DeadlineExceeded.new(timeout_seconds: 5, elapsed_seconds: 5),
        )
      end

      it 'does not cache the fallback' do
        described_class.call(query)

        allow(OpenaiClient).to receive(:call).and_return(ai_response)

        described_class.call(query)

        expect(OpenaiClient).to have_received(:call).twice
      end
    end

    describe '.clear_cache!' do
      it 'clears cached expansions' do
        described_class.call(query)
        described_class.clear_cache!
        described_class.call(query)

        expect(OpenaiClient).to have_received(:call).twice
      end
    end
  end

  describe 'inference cache' do
    let(:query) { 'laptop' }

    around do |example|
      Search::InferenceCache.store.clear
      example.run
    ensure
      Search::InferenceCache.store.clear
    end

    before { allow(TradeTariffBackend).to receive(:search_inference_cache_enabled?).and_return(true) }

    it 'reuses a successful expansion', :aggregate_failures do
      first = described_class.call(query)

      expect(described_class.call(query)).to eq(first)
      expect(OpenaiClient).to have_received(:call).once
    end

    it 'does not reuse a failed expansion' do
      allow(OpenaiClient).to receive(:call).and_raise(Faraday::TimeoutError)
      2.times { described_class.call(query) }

      expect(OpenaiClient).to have_received(:call).twice
    end

    it 'calls the model after a prompt change' do
      described_class.call(query)
      AdminConfiguration.where(name: 'expand_query_context').first.update(value: Sequel.pg_jsonb_wrap('Expand: %{search_query}'))
      described_class.call(query)

      expect(OpenaiClient).to have_received(:call).twice
    end
  end
end
