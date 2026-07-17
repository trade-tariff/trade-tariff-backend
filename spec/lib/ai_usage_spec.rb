RSpec.describe AiUsage do
  describe '.metadata_for' do
    before do
      allow(TradeTariffBackend).to receive(:openai_model_pricing).and_return({
        'gpt-test' => { 'input_per_million_tokens' => 2.0, 'cached_input_per_million_tokens' => 0.5, 'output_per_million_tokens' => 8.0 },
      })
    end

    it 'calculates chat completion costs from configured model pricing' do
      usage = described_class.metadata_for(
        model: 'gpt-test',
        event_kind: 'interactive_search',
        usage: { 'prompt_tokens' => 1_000, 'completion_tokens' => 250, 'total_tokens' => 1_250 },
      )

      expect(usage.to_h).to include(
        provider: 'openai',
        model: 'gpt-test',
        event_kind: 'interactive_search',
        input_tokens: 1_000,
        cached_input_tokens: nil,
        output_tokens: 250,
        total_tokens: 1_250,
        input_cost_usd: 0.002,
        cached_input_cost_usd: nil,
        output_cost_usd: 0.002,
        total_cost_usd: 0.004,
        pricing_known: true,
      )
    end

    it 'charges cached input tokens at the configured discounted rate' do
      usage = described_class.metadata_for(
        model: 'gpt-test',
        event_kind: 'interactive_search',
        usage: {
          'prompt_tokens' => 1_000,
          'prompt_tokens_details' => { 'cached_tokens' => 400 },
          'completion_tokens' => 250,
          'total_tokens' => 1_250,
        },
      )

      expect(usage.to_h).to include(
        cached_input_tokens: 400,
        input_cost_usd: 0.0014,
        cached_input_cost_usd: 0.0002,
        total_cost_usd: be_within(1e-12).of(0.0034),
        pricing_known: true,
      )
    end

    it 'does not report a negative cost when cached tokens exceed input tokens' do
      usage = described_class.metadata_for(
        model: 'gpt-test',
        event_kind: 'interactive_search',
        usage: {
          'prompt_tokens' => 100,
          'prompt_tokens_details' => { 'cached_tokens' => 150 },
          'completion_tokens' => 0,
          'total_tokens' => 100,
        },
      )

      expect(usage.to_h).to include(
        input_cost_usd: 0.000075,
        cached_input_cost_usd: 0.000075,
        total_cost_usd: 0.000075,
        pricing_known: true,
      )
    end

    it 'marks unknown model pricing without treating it as zero-cost' do
      usage = described_class.metadata_for(
        model: 'unpriced-model',
        event_kind: 'label_generation',
        usage: { 'prompt_tokens' => 100, 'completion_tokens' => 50, 'total_tokens' => 150 },
      )

      expect(usage.to_h).to include(
        model: 'unpriced-model',
        input_tokens: 100,
        output_tokens: 50,
        total_tokens: 150,
        input_cost_usd: nil,
        output_cost_usd: nil,
        total_cost_usd: nil,
        pricing_known: false,
      )
    end

    it 'marks chat completion pricing unknown when output token pricing is missing' do
      allow(TradeTariffBackend).to receive(:openai_model_pricing).and_return({
        'partial-model' => { 'input_per_million_tokens' => 2.0 },
      })

      usage = described_class.metadata_for(
        model: 'partial-model',
        event_kind: 'interactive_search',
        usage: { 'prompt_tokens' => 100, 'completion_tokens' => 50, 'total_tokens' => 150 },
      )

      expect(usage.to_h).to include(
        input_cost_usd: 0.0002,
        output_cost_usd: nil,
        total_cost_usd: 0.0002,
        pricing_known: false,
      )
    end

    it 'marks pricing unknown when configured prices are invalid' do
      allow(TradeTariffBackend).to receive(:openai_model_pricing).and_return({
        'invalid-model' => { 'input_per_million_tokens' => 'not-a-number', 'output_per_million_tokens' => 8.0 },
      })

      usage = described_class.metadata_for(
        model: 'invalid-model',
        event_kind: 'interactive_search',
        usage: { 'prompt_tokens' => 100, 'completion_tokens' => 50, 'total_tokens' => 150 },
      )

      expect(usage.to_h).to include(
        input_cost_usd: nil,
        output_cost_usd: 0.0004,
        total_cost_usd: 0.0004,
        pricing_known: false,
      )
    end

    it 'ignores unexpected usage shapes without failing the AI call' do
      usage = described_class.metadata_for(
        model: 'gpt-test',
        event_kind: 'interactive_search',
        usage: 'unexpected',
      )

      expect(usage.to_h).to include(
        input_tokens: nil,
        output_tokens: nil,
        total_tokens: 0,
        total_cost_usd: nil,
      )
    end
  end

  describe '.attach_metadata' do
    let(:metadata) do
      described_class::Metadata.new(
        provider: 'openai',
        model: 'gpt-test',
        event_kind: 'search_query_expansion',
        input_tokens: 10,
        cached_input_tokens: nil,
        output_tokens: 5,
        total_tokens: 15,
        input_cost_usd: nil,
        cached_input_cost_usd: nil,
        output_cost_usd: nil,
        total_cost_usd: nil,
        pricing_known: false,
      )
    end

    it 'attaches usage metadata without changing the returned object shape' do
      response = { 'expanded_query' => 'horses' }

      result = described_class.attach_metadata(response, metadata)

      expect(result).to equal(response)
      expect(result).to eq('expanded_query' => 'horses')
      expect(described_class.metadata_from(result)).to eq(metadata)
    end

    it 'does not fail when the parsed response is a scalar JSON value' do
      expect(described_class.attach_metadata(1, metadata)).to eq(1)
      expect(described_class.attach_metadata(true, metadata)).to be(true)
      expect(described_class.attach_metadata(nil, metadata)).to be_nil
    end

    it 'attaches usage metadata to string responses without changing the returned value' do
      response = 'not json'

      result = described_class.attach_metadata(response, metadata)

      expect(result).to equal(response)
      expect(result).to eq('not json')
      expect(described_class.metadata_from(result)).to eq(metadata)
    end
  end
end
