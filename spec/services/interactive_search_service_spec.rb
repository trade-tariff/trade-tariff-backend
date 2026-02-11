RSpec.describe InteractiveSearchService do
  subject(:result) { described_class.call(**params) }

  let(:params) do
    {
      query: query,
      expanded_query: expanded_query,
      opensearch_results: opensearch_results,
      answers: answers,
      request_id: request_id,
    }
  end

  let(:query) { 'leather handbag' }
  let(:expanded_query) { 'leather handbag travel bag accessory' }
  let(:request_id) { 'test-request-123' }
  let(:answers) { [] }

  let(:opensearch_results) do
    [
      build_result('4202210000', 'Handbags with outer surface of leather', 10.5),
      build_result('4202220000', 'Handbags with outer surface of plastic', 8.3),
      build_result('4202290000', 'Other handbags', 6.1),
    ]
  end

  let(:default_search_context) do
    <<~CONTEXT
      You are a UK trade tariff classification assistant.
      Search query: %{search_input}
      OpenSearch results: %{answers_opensearch}
      Previous Q&A: %{questions}
      Respond with JSON containing either "questions" or "answers".
    CONTEXT
  end

  before do
    allow(TradeTariffBackend).to receive(:ai_model).and_return('gpt-5.2')
    allow(Search::Instrumentation).to receive(:api_call).and_yield
    allow(Search::Instrumentation).to receive(:question_returned)
    allow(Search::Instrumentation).to receive(:answer_returned)
    allow(Search::Instrumentation).to receive(:search_failed)
    create(:admin_configuration, :boolean, name: 'interactive_search_enabled', value: true, area: 'classification')
    create(:admin_configuration, :integer, name: 'interactive_search_max_questions', value: 3, area: 'classification')
    create(:admin_configuration, name: 'search_context', value: default_search_context, area: 'classification')
  end

  def build_result(code, description, score)
    OpenStruct.new(
      goods_nomenclature_item_id: code,
      description: description,
      score: score,
    )
  end

  describe '.call' do
    context 'when feature is disabled' do
      before do
        config = AdminConfiguration.where(name: 'interactive_search_enabled').first
        config.update(value: Sequel.pg_jsonb_wrap(false))
        AdminConfiguration.refresh!(concurrently: false)
      end

      it 'returns nil' do
        expect(result).to be_nil
      end

      it 'does not call the AI client' do
        allow(OpenaiClient).to receive(:call)
        result
        expect(OpenaiClient).not_to have_received(:call)
      end
    end

    context 'when there is a single search result' do
      let(:opensearch_results) do
        [build_result('4202210000', 'Handbags with outer surface of leather', 10.5)]
      end

      it 'returns an answers result immediately' do
        expect(result.type).to eq(:answers)
      end

      it 'returns the single result with strong confidence' do
        expect(result.data).to eq([{ commodity_code: '4202210000', confidence: 'strong' }])
      end

      it 'does not call the AI client' do
        allow(OpenaiClient).to receive(:call)
        result
        expect(OpenaiClient).not_to have_received(:call)
      end
    end

    context 'when there are no search results' do
      let(:opensearch_results) { [] }

      it 'returns an error result' do
        expect(result.type).to eq(:error)
      end

      it 'includes an appropriate error message' do
        expect(result.data[:message]).to eq('No search results found')
      end
    end

    context 'when max questions reached' do
      let(:answers) do
        [
          { question: 'Q1', answer: 'A1' },
          { question: 'Q2', answer: 'A2' },
          { question: 'Q3', answer: 'A3' },
          { question: 'Q4', answer: 'A4' },
        ]
      end

      let(:ai_response) do
        '{"answers": [{"commodity_code": "4202210000", "confidence": "Strong"}]}'
      end

      before do
        allow(OpenaiClient).to receive(:call).and_return(ai_response)
      end

      it 'calls the AI with the final answer instruction' do
        result

        expect(OpenaiClient).to have_received(:call).with(
          a_string_including('you MUST now provide your best answer'),
          model: anything,
        )
      end

      it 'returns an answers result' do
        expect(result.type).to eq(:answers)
      end

      it 'falls back to best available answers when AI returns questions' do
        allow(OpenaiClient).to receive(:call).and_return(
          '{"questions": [{"question": "What colour?", "options": ["Red", "Blue"]}]}',
        )

        expect(result.type).to eq(:answers)
        expect(result.data.first[:confidence]).to eq('good')
      end
    end

    context 'when AI returns questions' do
      let(:ai_response) do
        '{"questions": [{"question": "What is the material?", "options": ["Leather", "Synthetic"]}]}'
      end

      before do
        allow(OpenaiClient).to receive(:call).and_return(ai_response)
      end

      it 'returns a questions result' do
        expect(result.type).to eq(:questions)
      end

      it 'includes the question data' do
        expect(result.data.first[:question]).to eq('What is the material?')
        expect(result.data.first[:options]).to eq(%w[Leather Synthetic])
      end

      it 'returns only one question at a time' do
        expect(result.data.size).to eq(1)
      end

      it 'includes the attempt number' do
        expect(result.attempt).to eq(1)
      end

      it 'includes the model used' do
        expect(result.model).to eq('gpt-5.2')
      end
    end

    context 'when AI returns answers' do
      let(:ai_response) do
        <<~JSON
          {"answers": [
            {"commodity_code": "4202210000", "confidence": "Strong"},
            {"commodity_code": "4202290000", "confidence": "Good"}
          ]}
        JSON
      end

      before do
        allow(OpenaiClient).to receive(:call).and_return(ai_response)
      end

      it 'returns an answers result' do
        expect(result.type).to eq(:answers)
      end

      it 'includes the commodity codes with normalized confidence' do
        expect(result.data).to include(
          { commodity_code: '4202210000', confidence: 'strong' },
        )
      end

      it 'sorts answers by confidence' do
        expect(result.data.first[:confidence]).to eq('strong')
      end
    end

    context 'when AI returns hallucinated codes' do
      let(:ai_response) do
        <<~JSON
          {"answers": [
            {"commodity_code": "4202210000", "confidence": "Strong"},
            {"commodity_code": "9999999999", "confidence": "Strong"},
            {"commodity_code": "4202290000", "confidence": "Good"}
          ]}
        JSON
      end

      before do
        allow(OpenaiClient).to receive(:call).and_return(ai_response)
      end

      it 'filters out codes not in opensearch results' do
        codes = result.data.map { |a| a[:commodity_code] }
        expect(codes).not_to include('9999999999')
      end

      it 'keeps valid codes' do
        codes = result.data.map { |a| a[:commodity_code] }
        expect(codes).to include('4202210000', '4202290000')
      end
    end

    context 'when AI returns all hallucinated codes' do
      let(:ai_response) do
        '{"answers": [{"commodity_code": "9999999999", "confidence": "Strong"}]}'
      end

      before do
        allow(OpenaiClient).to receive(:call).and_return(ai_response)
      end

      it 'falls back to best available answers' do
        expect(result.type).to eq(:answers)
        expect(result.data.first[:commodity_code]).to eq('4202210000')
      end
    end

    context 'when AI returns an error' do
      let(:ai_response) { '{"error": "Contradictory answers given"}' }

      before do
        allow(OpenaiClient).to receive(:call).and_return(ai_response)
      end

      it 'returns an error result' do
        expect(result.type).to eq(:error)
      end

      it 'includes the error message' do
        expect(result.data[:message]).to eq('Contradictory answers given')
      end
    end

    context 'when AI client raises an error' do
      before do
        allow(Search::Instrumentation).to receive(:api_call).and_raise(Faraday::TimeoutError)
      end

      it 'returns nil for graceful degradation' do
        expect(result).to be_nil
      end

      it 'emits a search_failed event' do
        result
        expect(Search::Instrumentation).to have_received(:search_failed).with(
          hash_including(error_type: 'Faraday::TimeoutError', search_type: 'interactive'),
        )
      end
    end

    context 'when AI returns unparseable response' do
      let(:ai_response) { 'Sorry, I cannot help with that request.' }

      before do
        allow(OpenaiClient).to receive(:call).and_return(ai_response)
      end

      it 'falls back to best available answers' do
        expect(result.type).to eq(:answers)
      end
    end

    context 'when processing follow-up with previous answers' do
      let(:answers) do
        [{ question: 'What is the material?', answer: 'Leather' }]
      end
      let(:ai_response) do
        '{"answers": [{"commodity_code": "4202210000", "confidence": "Strong"}]}'
      end

      before do
        allow(OpenaiClient).to receive(:call).and_return(ai_response)
      end

      it 'includes previous Q&A in context' do
        result

        expect(OpenaiClient).to have_received(:call).with(
          a_string_including('Leather'),
          model: 'gpt-5.2',
        )
      end

      it 'increments the attempt counter' do
        expect(result.attempt).to eq(2)
      end
    end
  end

  describe 'question extraction' do
    before do
      allow(OpenaiClient).to receive(:call).and_return(ai_response)
    end

    context 'when AI returns plain string questions' do
      let(:ai_response) { '{"questions": ["Is this for commercial use?"]}' }

      it 'handles string questions with default options' do
        expect(result.data.first[:question]).to eq('Is this for commercial use?')
        expect(result.data.first[:options]).to eq(%w[Yes No])
      end
    end
  end

  describe 'confidence normalization' do
    let(:ai_response) do
      <<~JSON
        {"answers": [
          {"commodity_code": "4202210000", "confidence": "STRONG"},
          {"commodity_code": "4202220000", "confidence": "good"},
          {"commodity_code": "4202290000", "confidence": "unknown"}
        ]}
      JSON
    end

    before do
      allow(OpenaiClient).to receive(:call).and_return(ai_response)
    end

    it 'normalizes confidence to lowercase' do
      confidences = result.data.map { |a| a[:confidence] }
      expect(confidences).to include('strong', 'good')
    end

    it 'defaults unknown confidence to possible' do
      unknown_code = result.data.find { |a| a[:commodity_code] == '4202290000' }
      expect(unknown_code[:confidence]).to eq('possible')
    end
  end

  describe 'AdminConfiguration integration' do
    let(:ai_response) { '{"answers": [{"commodity_code": "4202210000", "confidence": "Strong"}]}' }

    before do
      allow(OpenaiClient).to receive(:call).and_return(ai_response)
    end

    context 'when search_model config exists' do
      before do
        create(:admin_configuration, :options,
               name: 'search_model',
               area: 'classification',
               value: {
                 'selected' => 'gpt-4.1-mini-2025-04-14',
                 'options' => [
                   { 'key' => 'gpt-4.1-mini-2025-04-14', 'label' => 'GPT-4.1 Mini' },
                 ],
               })
      end

      it 'uses the configured model' do
        result

        expect(OpenaiClient).to have_received(:call).with(
          anything,
          model: 'gpt-4.1-mini-2025-04-14',
        )
      end
    end

    context 'when search_context config exists' do
      before do
        AdminConfiguration.where(name: 'search_context').first.update(value: Sequel.pg_jsonb_wrap('Custom prompt: %{search_input}'))
        AdminConfiguration.refresh!(concurrently: false)
      end

      it 'uses the configured context' do
        result

        expect(OpenaiClient).to have_received(:call).with(
          a_string_including('Custom prompt: leather handbag'),
          anything,
        )
      end
    end

    context 'when search_context includes %{expanded_query} placeholder' do
      before do
        AdminConfiguration.where(name: 'search_context').first.update(
          value: Sequel.pg_jsonb_wrap('Query: %{search_input} Expanded: %{expanded_query}'),
        )
        AdminConfiguration.refresh!(concurrently: false)
      end

      it 'substitutes both the original and expanded query' do
        result

        expect(OpenaiClient).to have_received(:call).with(
          a_string_including('Query: leather handbag Expanded: leather handbag travel bag accessory'),
          anything,
        )
      end
    end

    context 'when expanded_query is the same as the original query' do
      let(:expanded_query) { 'leather handbag' }

      before do
        AdminConfiguration.where(name: 'search_context').first.update(
          value: Sequel.pg_jsonb_wrap('Query: %{search_input} Expanded: %{expanded_query}'),
        )
        AdminConfiguration.refresh!(concurrently: false)
      end

      it 'substitutes both with the same value' do
        result

        expect(OpenaiClient).to have_received(:call).with(
          a_string_including('Query: leather handbag Expanded: leather handbag'),
          anything,
        )
      end
    end

    context 'when expanded_query is nil' do
      let(:expanded_query) { nil }

      before do
        AdminConfiguration.where(name: 'search_context').first.update(
          value: Sequel.pg_jsonb_wrap('Query: %{search_input} Expanded: %{expanded_query}'),
        )
        AdminConfiguration.refresh!(concurrently: false)
      end

      it 'substitutes expanded_query with empty string' do
        result

        expect(OpenaiClient).to have_received(:call).with(
          a_string_including('Query: leather handbag Expanded: '),
          anything,
        )
      end
    end
  end

  describe 'Result struct' do
    let(:ai_response) { '{"answers": [{"commodity_code": "4202210000", "confidence": "Strong"}]}' }

    before do
      allow(OpenaiClient).to receive(:call).and_return(ai_response)
    end

    it 'returns an InteractiveSearchService::Result' do
      expect(result).to be_a(described_class::Result)
    end

    it 'responds to type' do
      expect(result).to respond_to(:type)
    end

    it 'responds to data' do
      expect(result).to respond_to(:data)
    end

    it 'responds to attempt' do
      expect(result).to respond_to(:attempt)
    end

    it 'responds to model' do
      expect(result).to respond_to(:model)
    end

    it 'responds to result_limit' do
      expect(result).to respond_to(:result_limit)
    end

    it 'includes the configured result limit' do
      expect(result.result_limit).to eq(0)
    end
  end

  describe 'search_result_limit configuration' do
    let(:ai_response) do
      <<~JSON
        {"answers": [
          {"commodity_code": "4202210000", "confidence": "Strong"},
          {"commodity_code": "4202220000", "confidence": "Good"},
          {"commodity_code": "4202290000", "confidence": "Possible"}
        ]}
      JSON
    end

    before do
      allow(OpenaiClient).to receive(:call).and_return(ai_response)
    end

    context 'when search_result_limit config exists' do
      before do
        create(:admin_configuration, :integer, name: 'search_result_limit', value: 3, area: 'classification')
      end

      it 'uses the configured limit' do
        expect(result.result_limit).to eq(3)
      end

      it 'limits the number of answers returned' do
        expect(result.data.size).to be <= 3
      end
    end

    context 'when search_result_limit config is not set' do
      it 'defaults to 5' do
        expect(result.result_limit).to eq(0)
      end
    end
  end
end
