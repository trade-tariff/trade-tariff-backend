RSpec.describe InteractiveSearchService do
  subject(:result) { described_class.call(**params) }

  let(:search_result_class) { Data.define(:goods_nomenclature_item_id, :description, :full_description, :score) }
  let(:params) { search_params }

  def search_params(**overrides)
    {
      query: 'leather handbag',
      expanded_query: 'leather handbag travel bag accessory',
      opensearch_results: default_search_results,
      answers: [],
      request_id: 'test-request-123',
    }.merge(overrides)
  end

  def default_search_results
    [
      build_result('4202210000', 'Handbags with outer surface of leather', 10.5),
      build_result('4202220000', 'Handbags with outer surface of plastic', 8.3),
      build_result('4202290000', 'Other handbags', 6.1),
    ]
  end

  def default_search_context
    <<~CONTEXT
      You are a UK trade tariff classification assistant.
      General rules: %{general_rules}
      Search query: %{search_input}
      Relevant compressed notes: %{compressed_notes}
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
    allow(Search::Instrumentation).to receive(:duplicate_question_guard_checked)
    allow(Search::Instrumentation).to receive(:note_evidence_evaluated)
    allow(Search::Instrumentation).to receive(:search_failed)
    create(:admin_configuration, :boolean, name: 'interactive_search_enabled', value: true, area: 'classification')
    create(:admin_configuration, :integer, name: 'interactive_search_max_questions', value: 3, area: 'classification')
    create(:admin_configuration, name: 'search_context', value: default_search_context, area: 'classification')
    create(
      :admin_configuration,
      name: 'interactive_search_duplicate_question_guard_context',
      config_type: 'markdown',
      area: 'classification',
      value: AdminConfigurationSeeder.duplicate_question_guard_context_markdown,
      description: 'Validator prompt',
    )
  end

  def build_result(code, description, score, full_description: nil)
    search_result_class.new(
      goods_nomenclature_item_id: code,
      description: description,
      full_description: full_description,
      score: score,
    )
  end

  describe '.call' do
    context 'when max_rounds is passed explicitly' do
      it 'reaches the final-answer path using the given max_rounds instead of interactive_search_max_questions' do
        allow(OpenaiClient).to receive(:call).and_return('{"answers": [{"commodity_code": "4202210000", "confidence": "strong"}]}')

        described_class.call(**search_params(max_rounds: 0))

        expect(Search::Instrumentation).to have_received(:api_call).with(hash_including(operation: 'interactive_search_final_answer'))
      end
    end

    context 'when question_model is passed explicitly' do
      it 'uses the given question_model instead of the configured search_model' do
        allow(OpenaiClient).to receive(:call).and_return('{"answers": [{"commodity_code": "4202210000", "confidence": "strong"}]}')

        described_class.call(**search_params(question_model: 'gpt-4o-mini'))

        expect(OpenaiClient).to have_received(:call).with(
          anything, model: 'gpt-4o-mini', reasoning_effort: anything, event_kind: 'interactive_search'
        )
      end

      # See "reasoning_effort" contexts below for the exact effort value expected
      # in each scenario (no override, non-reasoning model, compatible/incompatible
      # reasoning levels) — this fixes a bug where an overridden question_model could
      # be sent a reasoning_effort value it does not support.

      context 'without a question_model override' do
        it 'sends the configured search_model reasoning_effort unchanged' do
          allow(OpenaiClient).to receive(:call).and_return('{"answers": [{"commodity_code": "4202210000", "confidence": "strong"}]}')

          described_class.call(**search_params)

          expect(OpenaiClient).to have_received(:call).with(
            anything, model: 'gpt-5.4', reasoning_effort: 'medium', event_kind: 'interactive_search'
          )
        end
      end

      context 'when overridden to a non-reasoning model' do
        it 'omits reasoning_effort instead of reusing the configured search_model value' do
          allow(OpenaiClient).to receive(:call).and_return('{"answers": [{"commodity_code": "4202210000", "confidence": "strong"}]}')

          described_class.call(**search_params(question_model: 'gpt-4o-mini'))

          expect(OpenaiClient).to have_received(:call).with(
            anything, model: 'gpt-4o-mini', reasoning_effort: nil, event_kind: 'interactive_search'
          )
        end
      end

      context 'when overridden to a reasoning model whose levels include the configured effort' do
        it 'passes the configured reasoning_effort through unchanged' do
          allow(OpenaiClient).to receive(:call).and_return('{"answers": [{"commodity_code": "4202210000", "confidence": "strong"}]}')

          # Default configured search_model reasoning_effort is 'medium' (NESTED_OPTION_DEFAULTS),
          # and gpt-5.2's reasoning_levels (%w[none low medium high]) include 'medium'.
          described_class.call(**search_params(question_model: 'gpt-5.2'))

          expect(OpenaiClient).to have_received(:call).with(
            anything, model: 'gpt-5.2', reasoning_effort: 'medium', event_kind: 'interactive_search'
          )
        end
      end

      context 'when overridden to a reasoning model whose levels do not include the configured effort' do
        before do
          create(:admin_configuration, :nested_options,
                 name: 'search_model',
                 area: 'classification',
                 value: {
                   'selected' => 'gpt-5.5',
                   'sub_values' => { 'reasoning_effort' => 'xhigh' },
                   'options' => [
                     { 'key' => 'gpt-5.5', 'label' => 'GPT-5.5', 'sub_options' => {} },
                   ],
                 })
        end

        it 'falls back to the most conservative level supported by the overridden model' do
          allow(OpenaiClient).to receive(:call).and_return('{"answers": [{"commodity_code": "4202210000", "confidence": "strong"}]}')

          # gpt-5.2's reasoning_levels (%w[none low medium high]) do not include the
          # configured 'xhigh', so the most conservative level ('none') is used instead.
          described_class.call(**search_params(question_model: 'gpt-5.2'))

          expect(OpenaiClient).to have_received(:call).with(
            anything, model: 'gpt-5.2', reasoning_effort: 'none', event_kind: 'interactive_search'
          )
        end
      end
    end

    context 'when search_type is passed explicitly and the call raises' do
      it 'tags the failure instrumentation with the given search_type instead of the hardcoded default' do
        allow(OpenaiClient).to receive(:call).and_raise(StandardError, 'boom')
        allow(Search::Instrumentation).to receive(:search_failed)

        described_class.call(**search_params(search_type: 'evaluation'))

        expect(Search::Instrumentation).to have_received(:search_failed).with(
          hash_including(search_type: 'evaluation'),
        )
      end
    end

    context 'when search_type is not given' do
      it 'still tags failure instrumentation as interactive, reproducing today\'s exact behaviour' do
        allow(OpenaiClient).to receive(:call).and_raise(StandardError, 'boom')
        allow(Search::Instrumentation).to receive(:search_failed)

        described_class.call(**search_params)

        expect(Search::Instrumentation).to have_received(:search_failed).with(
          hash_including(search_type: 'interactive'),
        )
      end
    end

    context 'when feature is disabled' do
      before do
        config = AdminConfiguration.where(name: 'interactive_search_enabled').first
        config.update(value: Sequel.pg_jsonb_wrap(false))
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
      let(:params) do
        search_params(
          opensearch_results: [build_result('4202210000', 'Handbags with outer surface of leather', 10.5)],
        )
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
      let(:params) { search_params(opensearch_results: []) }

      it 'returns an error result' do
        expect(result.type).to eq(:error)
      end

      it 'includes an appropriate error message' do
        expect(result.data[:message]).to eq('No search results found')
      end
    end

    context 'when max questions reached' do
      let(:params) do
        search_params(answers: [
          { question: 'Q1', answer: 'A1' },
          { question: 'Q2', answer: 'A2' },
          { question: 'Q3', answer: 'A3' },
        ])
      end

      let(:ai_response) do
        '{"answers": [{"commodity_code": "4202210000", "confidence": "Strong"}]}'
      end

      before do
        allow(OpenaiClient).to receive(:call).and_return(ai_response)
        allow(Search::Instrumentation).to receive(:api_call).and_yield
      end

      it 'calls the AI with the final answer instruction' do
        result

        expect(OpenaiClient).to have_received(:call).with(
          a_string_including('you MUST now provide your best answer'),
          model: anything,
          reasoning_effort: anything,
          event_kind: 'interactive_search_final_answer',
        )
      end

      it 'returns an answers result' do
        expect(result.type).to eq(:answers)
      end

      it 'instruments the final answer call' do
        result

        expect(Search::Instrumentation).to have_received(:api_call).with(
          request_id: params[:request_id],
          model: 'gpt-5.4',
          attempt_number: 4,
          iteration: 4,
          effective_query: params[:expanded_query],
          operation: 'interactive_search_final_answer',
        )
      end

      it 'falls back to best available answers when AI returns questions' do
        allow(OpenaiClient).to receive(:call).and_return(
          '{"questions": [{"question": "What colour?", "options": ["Red", "Blue"]}]}',
        )

        expect(result.type).to eq(:answers)
        expect(result.data.first[:confidence]).to eq('good')
      end

      it 'returns an error result when AI returns a structured error' do
        allow(OpenaiClient).to receive(:call).and_return(
          '{"error": "Contradictory answers given"}',
        )

        expect(result.type).to eq(:error)
        expect(result.data[:message]).to eq('Contradictory answers given')
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
        expect(result.model).to eq('gpt-5.4')
      end

      it 'instruments the question iteration' do
        result

        expect(Search::Instrumentation).to have_received(:question_returned).with(
          hash_including(
            attempt_number: 1,
            iteration: 1,
            effective_query: params[:expanded_query],
          ),
        )
      end
    end

    context 'when AI returns a duplicate question' do
      let(:params) do
        query = 'Universal Probe Test Leads Cable Digital Multimeter 1000V 10A Cat.2 for Electrical Testing (2 Pcs)'
        search_params(
          query:,
          expanded_query: "#{query} Another electrical measuring or checking instrument",
          answers: [
            {
              question: 'What best describes the goods being imported?',
              answer: 'Another electrical measuring or checking instrument',
            },
            {
              question: 'Which of these best describes what is actually included in the imported product?',
              answer: 'Another electrical measuring or checking instrument',
            },
            {
              question: 'Which best describes the imported item itself?',
              answer: 'Another electrical measuring or checking instrument',
            },
          ],
        )
      end
      let(:duplicate_question_response) do
        <<~JSON
          {"questions": [{
            "question": "Which of these best matches the item being imported?",
            "options": [
              "A digital multimeter instrument",
              "A pair of multimeter test leads/probes with connectors",
              "Another electrical measuring or checking instrument",
              "An insulated electrical cable with connectors, not specifically for a measuring instrument"
            ]
          }]}
        JSON
      end

      before do
        create(
          :admin_configuration,
          :boolean,
          name: 'interactive_search_duplicate_question_guard_enabled',
          value: true,
          area: 'classification',
        )
        AdminConfiguration.where(name: 'interactive_search_max_questions').first.update(value: Sequel.pg_jsonb_wrap(7))
      end

      it 'retries once with corrective feedback and returns the retry response' do
        allow(OpenaiClient).to receive(:call) do |prompt, **|
          if prompt.include?('Decide whether a candidate guided-search question repeats')
            '{"duplicate": true, "reason": "Repeats the already answered item-identity distinction", "new_dimension": null}'
          elsif prompt.include?('The previous candidate question repeated')
            '{"questions": [{"question": "Which type of accessory is being imported?", "options": ["Probe or test lead", "Connector", "Carrying case"]}]}'
          else
            duplicate_question_response
          end
        end

        expect(result.type).to eq(:questions)
        expect(result.data.first[:question]).to eq('Which type of accessory is being imported?')
        expect(OpenaiClient).to have_received(:call).with(
          a_string_including('The previous candidate question repeated'),
          model: 'gpt-5.4',
          reasoning_effort: 'medium',
          event_kind: 'duplicate_question_retry',
        )
        expect(Search::Instrumentation).to have_received(:api_call).with(
          request_id: params[:request_id],
          model: 'gpt-5.4',
          attempt_number: 4,
          iteration: 4,
          effective_query: params[:expanded_query],
          operation: 'duplicate_question_retry',
        )
        expect(Search::Instrumentation).to have_received(:note_evidence_evaluated).with(
          hash_including(
            request_id: params[:request_id],
            iteration: 4,
            attempt_number: 4,
            operation: 'duplicate_question_retry',
          ),
        )
      end

      it 'falls back to best available answers when the retry also returns a duplicate question' do
        allow(OpenaiClient).to receive(:call) do |prompt, **|
          if prompt.include?('Decide whether a candidate guided-search question repeats')
            '{"duplicate": true, "reason": "Repeats the already answered item-identity distinction", "new_dimension": null}'
          else
            duplicate_question_response
          end
        end

        expect(result.type).to eq(:answers)
        expect(result.data.first).to eq({ commodity_code: '4202210000', confidence: 'good' })
      end

      it 'returns the duplicate-looking question without retry when the guard is disabled' do
        AdminConfiguration.where(name: 'interactive_search_duplicate_question_guard_enabled').first.update(value: Sequel.pg_jsonb_wrap(false))
        allow(OpenaiClient).to receive(:call).and_return(duplicate_question_response)

        expect(result.type).to eq(:questions)
        expect(result.data.first[:question]).to eq('Which of these best matches the item being imported?')
        expect(OpenaiClient).to have_received(:call).once
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
      let(:params) do
        search_params(answers: [{ question: 'What is the material?', answer: 'Leather' }])
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
          model: 'gpt-5.4',
          reasoning_effort: 'medium',
          event_kind: 'interactive_search',
        )
      end

      it 'increments the attempt counter' do
        expect(result.attempt).to eq(2)
      end

      it 'instruments answers with query iteration' do
        result

        expect(Search::Instrumentation).to have_received(:answer_returned).with(
          hash_including(
            attempt_number: 2,
            iteration: 2,
            effective_query: params[:expanded_query],
          ),
        )
      end
    end

    context 'when AI returns uncertainty options' do
      let(:ai_response) do
        %q({"questions": [{"question": "What is the material?", "options": ["Leather", "I don't know", "Unknown", "Other"]}]})
      end

      before do
        allow(OpenaiClient).to receive(:call).and_return(ai_response)
      end

      it 'removes uncertainty options but keeps Other as a catch-all option' do
        expect(result.data.first[:options]).to eq(%w[Leather Other])
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

  describe 'context formatting' do
    let(:ai_response) { '{"answers": [{"commodity_code": "4202210000", "confidence": "Strong"}]}' }

    before do
      allow(OpenaiClient).to receive(:call).and_return(ai_response)
    end

    context 'when search_compressed_notes_enabled is passed explicitly' do
      it 'records note evidence as enabled without needing a search_compressed_notes_enabled AdminConfiguration record' do
        described_class.call(**search_params(search_compressed_notes_enabled: true))

        expect(Search::Instrumentation).to have_received(:note_evidence_evaluated).with(
          hash_including(enabled: true),
        )
      end

      it 'records note evidence as disabled for an explicit false override, even when AdminConfiguration says true' do
        create(:admin_configuration, :boolean, name: 'search_compressed_notes_enabled', value: true, area: 'classification')
        allow(AdminConfiguration).to receive(:enabled?).and_call_original

        described_class.call(**search_params(search_compressed_notes_enabled: false))

        expect(Search::Instrumentation).to have_received(:note_evidence_evaluated).with(
          hash_including(enabled: false),
        )
        expect(AdminConfiguration).not_to have_received(:enabled?).with('search_compressed_notes_enabled')
      end
    end

    context 'when search_general_rules_enabled is passed explicitly' do
      let(:default_search_context) { AdminConfigurationSeeder.search_context_markdown }
      let(:general_rules_presenter) { instance_double(Search::GeneralRulesPresenter, to_s: "Current General Rules of Interpretation:\nUse headings first.") }

      before do
        allow(Search::GeneralRulesPresenter).to receive(:new).and_return(general_rules_presenter)
      end

      it 'includes general rules without needing a search_general_rules_enabled AdminConfiguration record' do
        described_class.call(**search_params(search_general_rules_enabled: true))

        expect(Search::GeneralRulesPresenter).to have_received(:new)
      end

      it 'excludes general rules for an explicit false override, even when AdminConfiguration says true' do
        create(:admin_configuration, :boolean, name: 'search_general_rules_enabled', value: true, area: 'classification')
        allow(AdminConfiguration).to receive(:enabled?).and_call_original

        described_class.call(**search_params(search_general_rules_enabled: false))

        expect(Search::GeneralRulesPresenter).not_to have_received(:new)
        expect(AdminConfiguration).not_to have_received(:enabled?).with('search_general_rules_enabled')
      end
    end

    it 'removes the compressed notes line when no compressed note contexts are selected' do
      result

      context_arg = nil
      expect(OpenaiClient).to have_received(:call) do |context, **_opts|
        context_arg = context
      end

      expect(context_arg).not_to include('Relevant compressed notes')
      expect(context_arg).not_to include('Relevant compressed notes: []')
      expect(context_arg).to include('OpenSearch results:')
    end

    it 'records that note evidence was disabled for the prompt' do
      create(:admin_configuration,
             :boolean,
             name: 'search_compressed_notes_enabled',
             value: false,
             area: 'classification')

      result

      expect(Search::Instrumentation).to have_received(:note_evidence_evaluated).with(
        request_id: 'test-request-123',
        query: 'leather handbag',
        effective_query: 'leather handbag travel bag accessory',
        iteration: 1,
        attempt_number: 1,
        operation: 'interactive_search',
        enabled: false,
        diagnostics: include(
          status: 'disabled',
          considered_note_count: 0,
          selected_note_count: 0,
          selected_contexts: [],
        ),
      )
    end

    context 'when the configured prompt wraps compressed notes in marker lines' do
      let(:default_search_context) do
        <<~CONTEXT
          Search query: %{search_input}
          -----------RELEVANT_COMPRESSED_NOTES-------
          %{compressed_notes}
          -----------END RELEVANT_COMPRESSED_NOTES---
          OpenSearch results: %{answers_opensearch}
          Previous Q&A: %{questions}
        CONTEXT
      end

      it 'removes the whole compressed notes marker section when no contexts are selected' do
        result

        context_arg = nil
        expect(OpenaiClient).to have_received(:call) do |context, **_opts|
          context_arg = context
        end

        expect(context_arg).not_to include('RELEVANT_COMPRESSED_NOTES')
        expect(context_arg).to include('OpenSearch results:')
      end
    end

    context 'when general rules are disabled by default' do
      let(:default_search_context) { AdminConfigurationSeeder.search_context_markdown }
      let(:general_rules_presenter) { instance_double(Search::GeneralRulesPresenter, to_s: 'GIR source text') }

      before do
        allow(Search::GeneralRulesPresenter).to receive(:new)
          .and_return(general_rules_presenter)
      end

      it 'does not load or include general rules' do
        result

        context_arg = nil
        expect(OpenaiClient).to have_received(:call) do |context, **_opts|
          context_arg = context
        end

        expect(Search::GeneralRulesPresenter).not_to have_received(:new)
        expect(context_arg).not_to include('GIR source text')
        expect(context_arg).not_to include('General Rules of Interpretation')
      end
    end

    context 'when general rules are enabled and available' do
      let(:general_rules_presenter) { instance_double(Search::GeneralRulesPresenter, to_s: "Current General Rules of Interpretation:\nUse headings first.") }

      before do
        create(:admin_configuration,
               :boolean,
               name: 'search_general_rules_enabled',
               value: true,
               area: 'classification')
        allow(Search::GeneralRulesPresenter).to receive(:new)
          .and_return(general_rules_presenter)
      end

      it 'adds the rules below the role description' do
        result

        context_arg = nil
        expect(OpenaiClient).to have_received(:call) do |context, **_opts|
          context_arg = context
        end

        expect(context_arg).to start_with("You are a UK trade tariff classification assistant.\nGeneral rules: Current General Rules of Interpretation:\nUse headings first.")
        expect(context_arg).to include('Search query: leather handbag')
      end

      it 'does not substitute prompt placeholders inside the rules' do
        allow(general_rules_presenter).to receive(:to_s)
          .and_return("Current General Rules of Interpretation:\nRule mentions %{search_input}.")

        result

        context_arg = nil
        expect(OpenaiClient).to have_received(:call) do |context, **_opts|
          context_arg = context
        end

        expect(context_arg).to include("General rules: Current General Rules of Interpretation:\nRule mentions %{search_input}.")
        expect(context_arg).to include('Search query: leather handbag')
      end

      context 'when max questions have been reached' do
        let(:params) do
          search_params(answers: [
            { question: 'Q1', answer: 'A1' },
            { question: 'Q2', answer: 'A2' },
            { question: 'Q3', answer: 'A3' },
          ])
        end

        it 'includes the rules in the final answer prompt once' do
          result

          context_arg = nil
          expect(OpenaiClient).to have_received(:call) do |context, **_opts|
            context_arg = context
          end

          expect(context_arg.scan('Current General Rules of Interpretation').size).to eq(1)
          expect(context_arg).to include(InteractiveSearchService::FINAL_ANSWER_INSTRUCTION.strip)
        end
      end
    end

    context 'when compressed note context is enabled' do
      before do
        create(
          :tariff_knowledge_node,
          :note_fragment,
          key: 'note_fragment:customs_tariff_chapter_note:1.31:42:0001',
          content: 'Heading 4202 includes handbags with outer surface of leather.',
          source_type: 'customs_tariff_chapter_note',
          source_id: '42',
        )
        metadata = {
          'evidence' => [
            {
              'source_node_key' => 'note_fragment:customs_tariff_chapter_note:1.31:42:0001',
              'source_type' => 'customs_tariff_chapter_note',
              'source_id' => '42',
              'source_title' => 'Chapter 42 notes fragment 1',
              'source_context' => 'Heading 4202 includes handbags with outer surface of leather.',
              'context_type' => 'inclusion',
              'range_type' => 'heading',
              'range_code' => '4202',
              'relationships' => [TariffKnowledge::Edge::APPLIES_TO],
            },
            {
              'source_node_key' => 'note_fragment:customs_tariff_general_rule:1.31:1:0001',
              'source_type' => 'customs_tariff_general_rule',
              'source_id' => '1',
              'source_title' => 'General Interpretive Rule 1 fragment 1',
              'source_context' => 'Leather handbag travel bag accessories must be classified according to the headings.',
              'context_type' => 'reference',
              'relationships' => [TariffKnowledge::Edge::APPLIES_TO],
            },
          ],
        }
        create(
          :tariff_knowledge_node,
          :note_fragment,
          key: 'note_fragment:customs_tariff_chapter_note:1.30:42:0001',
          content: 'Historic heading 4202 evidence should not be used.',
          source_type: 'customs_tariff_chapter_note',
          source_id: '42',
        )
        historic_metadata = {
          'evidence' => [
            {
              'source_node_key' => 'note_fragment:customs_tariff_chapter_note:1.30:42:0001',
              'source_type' => 'customs_tariff_chapter_note',
              'source_id' => '42',
              'source_title' => 'Historic Chapter 42 notes fragment 1',
              'source_context' => 'Historic heading 4202 evidence should not be used.',
              'context_type' => 'inclusion',
              'range_type' => 'heading',
              'range_code' => '4202',
              'relationships' => [TariffKnowledge::Edge::APPLIES_TO],
            },
          ],
        }
        create(:admin_configuration,
               :boolean,
               name: 'search_compressed_notes_enabled',
               value: true,
               area: 'classification')
        create(:tariff_knowledge_compressed_note,
               goods_nomenclature_item_id: '4202210000',
               content: 'Historic approved note.',
               context_hash: Digest::SHA256.hexdigest('Historic approved note.'),
               metadata: Sequel.pg_jsonb_wrap(historic_metadata),
               approved: true,
               stale: false,
               expired: false,
               generated_at: 2.days.ago)
        create(:tariff_knowledge_compressed_note,
               goods_nomenclature_item_id: '4202210000',
               content: 'Includes handbags with outer surface of leather. Excludes plastic sheeting.',
               context_hash: Digest::SHA256.hexdigest('Includes handbags with outer surface of leather. Excludes plastic sheeting.'),
               metadata: Sequel.pg_jsonb_wrap(metadata),
               approved: false,
               needs_review: false,
               stale: false,
               expired: false)
        create(:tariff_knowledge_compressed_note,
               goods_nomenclature_item_id: '4202220000',
               content: 'Rejected notes should not be consumed.',
               metadata: Sequel.pg_jsonb_wrap(metadata),
               approved: false,
               needs_review: true,
               stale: false,
               expired: false)
        create(:tariff_knowledge_compressed_note,
               goods_nomenclature_item_id: '4202290000',
               content: 'Includes handbags with outer surface of leather. Excludes plastic sheeting.',
               context_hash: Digest::SHA256.hexdigest('Includes handbags with outer surface of leather. Excludes plastic sheeting.'),
               metadata: Sequel.pg_jsonb_wrap(metadata),
               approved: false,
               needs_review: false,
               stale: false,
               expired: false)
        create(:tariff_knowledge_compressed_note,
               goods_nomenclature_item_id: '4202220000',
               content: 'Stale notes should not be consumed.',
               approved: true,
               needs_review: false,
               stale: true,
               expired: false)
      end

      context 'when no compressed notes qualify' do
        let(:params) do
          search_params(opensearch_results: [
            build_result('4202230000', 'Handbags with outer surface of textile materials', 7.1),
            build_result('4202240000', 'Other handbags', 6.8),
          ])
        end

        it 'removes the compressed notes line instead of sending an empty array' do
          result

          context_arg = nil
          expect(OpenaiClient).to have_received(:call) do |context, **_opts|
            context_arg = context
          end

          expect(context_arg).not_to include('Relevant compressed notes')
          expect(context_arg).not_to include('Relevant compressed notes: []')
          expect(context_arg).to include('OpenSearch results:')
        end
      end

      it 'adds current approved compressed notes once and references them from matching OpenSearch results' do
        result

        context_arg = nil
        expect(OpenaiClient).to have_received(:call) do |context, **_opts|
          context_arg = context
        end

        parsed_notes = JSON.parse(context_arg.match(/Relevant compressed notes: (.+?)OpenSearch/m)[1])
        parsed_results = JSON.parse(context_arg.match(/OpenSearch results: (.+?)Previous/m)[1])
        expect(parsed_notes).to contain_exactly(
          include(
            'note_ref' => 'compressed_note_1',
            'commodity_codes' => contain_exactly('4202210000', '4202290000'),
            'fragments' => contain_exactly(
              include(
                'source' => 'Chapter 42 notes fragment 1',
                'type' => 'inclusion',
                'text' => 'Heading 4202 includes handbags with outer surface of leather.',
              ),
            ),
          ),
        )
        expect(parsed_results.first).to include(
          'commodity_code' => '4202210000',
          'compressed_note_refs' => %w[compressed_note_1],
        )
        expect(parsed_results.second).not_to include('compressed_note')
        expect(parsed_results.second).not_to include('compressed_note_refs')
        expect(parsed_results.third).to include(
          'commodity_code' => '4202290000',
          'compressed_note_refs' => %w[compressed_note_1],
        )
        expect(context_arg).not_to include('Includes handbags with outer surface of leather. Excludes plastic sheeting.')
        expect(context_arg).not_to include('Historic heading 4202 evidence should not be used.')
        expect(context_arg).not_to include('Rejected notes should not be consumed.')
        expect(context_arg.scan('Heading 4202 includes handbags with outer surface of leather.').size).to eq(1)
      end

      it 'includes compressed GIR evidence only when the general-rules gate is enabled' do
        create(:admin_configuration,
               :boolean,
               name: 'search_general_rules_enabled',
               value: true,
               area: 'classification')

        result

        context_arg = nil
        expect(OpenaiClient).to have_received(:call) do |context, **_opts|
          context_arg = context
        end
        parsed_notes = JSON.parse(context_arg.match(/Relevant compressed notes: (.+?)OpenSearch/m)[1])

        expect(parsed_notes.first['fragments']).to include(
          include(
            'source' => 'General Interpretive Rule 1 fragment 1',
            'text' => 'Leather handbag travel bag accessories must be classified according to the headings.',
          ),
        )
      end

      it 'records the exact selected prompt evidence for the request iteration' do
        result

        expect(Search::Instrumentation).to have_received(:note_evidence_evaluated).with(
          request_id: 'test-request-123',
          query: 'leather handbag',
          effective_query: 'leather handbag travel bag accessory',
          iteration: 1,
          attempt_number: 1,
          operation: 'interactive_search',
          enabled: true,
          diagnostics: include(
            status: 'selected',
            selected_note_count: 1,
            selected_evidence_count: 1,
            selected_contexts: contain_exactly(
              include(
                context_hash: Digest::SHA256.hexdigest('Includes handbags with outer surface of leather. Excludes plastic sheeting.'),
                note_ref: 'compressed_note_1',
                commodity_codes: contain_exactly('4202210000', '4202290000'),
                evidence: contain_exactly(
                  include(
                    evidence_kind: 'note_fragment',
                    source_node_key: 'note_fragment:customs_tariff_chapter_note:1.31:42:0001',
                    text: 'Heading 4202 includes handbags with outer surface of leather.',
                    decision: 'selected',
                  ),
                ),
              ),
            ),
          ),
        )
      end

      it 'selects compressed note evidence using the expanded query for the current iteration' do
        allow(TariffKnowledge::RelevantNoteFragmentSelector).to receive(:call_with_diagnostics).and_call_original

        result

        expect(TariffKnowledge::RelevantNoteFragmentSelector).to have_received(:call_with_diagnostics).with(
          query: params[:expanded_query],
          search_results: params[:opensearch_results],
          notes_by_item_id: hash_including('4202210000', '4202290000'),
          source_types: %w[customs_tariff_chapter_note customs_tariff_section_note],
        )
      end

      context 'when the configured prompt has no compressed notes placeholder' do
        let(:default_search_context) do
          <<~CONTEXT
            Search query: %{search_input}
            OpenSearch results: %{answers_opensearch}
            Previous Q&A: %{questions}
          CONTEXT
        end

        it 'inserts the deduplicated notes before OpenSearch results' do
          result

          context_arg = nil
          expect(OpenaiClient).to have_received(:call) do |context, **_opts|
            context_arg = context
          end

          expect(context_arg).to match(/Relevant compressed notes: .+\nOpenSearch results:/)
          expect(context_arg.scan('Heading 4202 includes handbags with outer surface of leather.').size).to eq(1)
        end
      end
    end

    context 'when results have full_description' do
      let(:params) do
        search_params(opensearch_results: [
          build_result('4202210000', 'Other', 10.5, full_description: 'Handbags - Of leather or composition leather'),
          build_result('4202220000', 'Other', 8.3, full_description: 'Handbags - Of plastic sheeting or textile materials'),
        ])
      end

      it 'uses full_description in the context sent to the AI' do
        result

        expect(OpenaiClient).to have_received(:call).with(
          a_string_including('Handbags - Of leather or composition leather'),
          anything,
        )
      end

      it 'does not use the bare description' do
        result

        context_arg = nil
        expect(OpenaiClient).to have_received(:call) do |context, **_opts|
          context_arg = context
        end

        parsed_results = JSON.parse(context_arg.match(/OpenSearch results: (.+?)Previous/m)[1])
        descriptions = parsed_results.map { |r| r['description'] }
        expect(descriptions).not_to include('Other')
      end
    end

    context 'when results have no full_description' do
      let(:params) do
        search_params(opensearch_results: [
          build_result('4202210000', 'Handbags with outer surface of leather', 10.5),
          build_result('4202220000', 'Handbags with outer surface of plastic', 8.3),
        ])
      end

      it 'falls back to description' do
        result

        expect(OpenaiClient).to have_received(:call).with(
          a_string_including('Handbags with outer surface of leather'),
          anything,
        )
      end
    end
  end

  describe 'AdminConfiguration integration' do
    let(:ai_response) { '{"answers": [{"commodity_code": "4202210000", "confidence": "Strong"}]}' }

    before do
      allow(OpenaiClient).to receive(:call).and_return(ai_response)
    end

    context 'when search_model config exists' do
      before do
        create(:admin_configuration, :nested_options,
               name: 'search_model',
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
          event_kind: 'interactive_search',
        )
      end
    end

    context 'when search_context config exists' do
      before do
        AdminConfiguration.where(name: 'search_context').first.update(value: Sequel.pg_jsonb_wrap('Custom prompt: %{search_input}'))
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
      let(:params) { search_params(expanded_query: 'leather handbag') }

      before do
        AdminConfiguration.where(name: 'search_context').first.update(
          value: Sequel.pg_jsonb_wrap('Query: %{search_input} Expanded: %{expanded_query}'),
        )
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
      let(:params) { search_params(expanded_query: nil) }

      before do
        AdminConfiguration.where(name: 'search_context').first.update(
          value: Sequel.pg_jsonb_wrap('Query: %{search_input} Expanded: %{expanded_query}'),
        )
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
