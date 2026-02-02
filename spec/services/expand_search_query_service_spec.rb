RSpec.describe ExpandSearchQueryService do
  subject(:result) { described_class.call(query) }

  let(:ai_response) do
    {
      'expanded_query' => 'Portable automatic data-processing machines',
      'reason' => "The term 'laptop' is colloquial; tariff uses formal terminology.",
    }
  end

  before do
    allow(OpenaiClient).to receive(:call).and_return(ai_response)
  end

  describe '.call' do
    context 'when the query is a text search term' do
      let(:query) { 'laptop' }

      it 'returns the expanded query from the AI' do
        expect(result.expanded_query).to eq('Portable automatic data-processing machines')
      end

      it 'returns the reason for expansion' do
        expect(result.reason).to eq("The term 'laptop' is colloquial; tariff uses formal terminology.")
      end

      it 'calls the AI client with the expansion context' do
        result

        expect(OpenaiClient).to have_received(:call).with(
          a_string_including('laptop'),
          model: TradeTariffBackend.ai_model,
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
    end

    context 'when the AI returns an empty expanded_query' do
      let(:query) { 'laptop' }
      let(:ai_response) { { 'expanded_query' => '', 'reason' => 'empty' } }

      it 'falls back to the original query' do
        expect(result.expanded_query).to eq('laptop')
      end
    end

    context 'when the AI returns nil' do
      let(:query) { 'laptop' }
      let(:ai_response) { nil }

      it 'falls back to the original query' do
        expect(result.expanded_query).to eq('laptop')
      end
    end

    context 'when the AI client raises an error' do
      let(:query) { 'laptop' }

      before do
        allow(OpenaiClient).to receive(:call).and_raise(Faraday::TimeoutError)
      end

      it 'falls back to the original query' do
        expect(result.expanded_query).to eq('laptop')
      end

      it 'returns nil reason' do
        expect(result.reason).to be_nil
      end

      it 'logs the error' do
        allow(Rails.logger).to receive(:error)

        result

        expect(Rails.logger).to have_received(:error).with(/ExpandSearchQueryService error/)
      end
    end
  end

  describe 'AdminConfiguration integration' do
    let(:query) { 'laptop' }
    let(:classification_scope) { double('classification_scope') } # rubocop:disable RSpec/VerifiedDoubles

    before do
      allow(AdminConfiguration).to receive(:classification).and_return(classification_scope)
      allow(classification_scope).to receive(:by_name).and_return(nil)
    end

    context 'when expand_model config exists' do
      let(:model_config) do
        instance_double(
          AdminConfiguration,
          value: { 'selected' => 'gpt-4.1-mini-2025-04-14', 'options' => [] },
        )
      end

      before do
        allow(classification_scope).to receive(:by_name).with('expand_model').and_return(model_config)
      end

      it 'uses the configured model' do
        result

        expect(OpenaiClient).to have_received(:call).with(
          anything,
          model: 'gpt-4.1-mini-2025-04-14',
        )
      end
    end

    context 'when expand_query_context config exists' do
      let(:context_config) do
        instance_double(
          AdminConfiguration,
          value: 'Custom prompt for: %{search_query}',
        )
      end

      before do
        allow(classification_scope).to receive(:by_name).with('expand_query_context').and_return(context_config)
      end

      it 'uses the configured context with the query interpolated' do
        result

        expect(OpenaiClient).to have_received(:call).with(
          'Custom prompt for: laptop',
          model: TradeTariffBackend.ai_model,
        )
      end
    end

    context 'when no config exists' do
      it 'falls back to the I18n prompt' do
        result

        expect(OpenaiClient).to have_received(:call).with(
          a_string_including('rephrase and expand'),
          model: TradeTariffBackend.ai_model,
        )
      end
    end
  end

  describe 'Result struct' do
    let(:query) { 'laptop' }

    it 'returns an ExpandSearchQueryService::Result' do
      expect(result).to be_a(described_class::Result)
    end

    it 'responds to expanded_query' do
      expect(result).to respond_to(:expanded_query)
    end

    it 'responds to reason' do
      expect(result).to respond_to(:reason)
    end
  end
end
