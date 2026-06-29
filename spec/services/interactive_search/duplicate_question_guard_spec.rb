RSpec.describe InteractiveSearch::DuplicateQuestionGuard do
  subject(:result) do
    described_class.call(
      query: query,
      effective_query: effective_query,
      answers: answers,
      candidate_question: candidate_question,
      request_id: request_id,
      attempt_number: attempt_number,
    )
  end

  let(:query) { 'Universal Probe Test Leads Cable Digital Multimeter 1000V 10A Cat.2 for Electrical Testing (2 Pcs)' }
  let(:effective_query) { "#{query} Another electrical measuring or checking instrument" }
  let(:request_id) { '946abaa4-f4e4-4924-a876-de8dd51cde8f' }
  let(:attempt_number) { 4 }
  let(:answers) do
    [
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
    ]
  end
  let(:candidate_question) do
    {
      question: 'Which of these best matches the item being imported?',
      options: [
        'A digital multimeter instrument',
        'A pair of multimeter test leads/probes with connectors',
        'Another electrical measuring or checking instrument',
        'An insulated electrical cable with connectors, not specifically for a measuring instrument',
      ],
    }
  end

  before do
    create(
      :admin_configuration,
      :boolean,
      name: 'interactive_search_duplicate_question_guard_enabled',
      value: true,
      area: 'classification',
    )
    create(
      :admin_configuration,
      name: 'interactive_search_duplicate_question_guard_context',
      config_type: 'markdown',
      area: 'classification',
      value: AdminConfigurationSeeder.duplicate_question_guard_context_markdown,
      description: 'Validator prompt',
    )
  end

  it 'rejects the AI-907 duplicate item-identity question' do
    allow(OpenaiClient).to receive(:call).and_return(
      '{"duplicate": true, "reason": "Repeats the already answered item-identity distinction", "duplicate_of_question": "Which best describes the imported item itself?", "duplicate_of_answer": "Another electrical measuring or checking instrument", "new_dimension": null}',
    )

    expect(result).not_to be_allowed
    expect(result).to be_duplicate
    expect(result.duplicate_of_question).to eq('Which best describes the imported item itself?')
    expect(result.duplicate_of_answer).to eq('Another electrical measuring or checking instrument')
    expect(result.suspicious).to be(true)
    expect(result.signals).to include('repeated_selected_answer', 'broad_item_identity_stem')
    expect(result.reason).to eq('Repeats the already answered item-identity distinction')
    expect(OpenaiClient).to have_received(:call).with(
      anything,
      model: 'gpt-5-nano-2025-08-07',
      reasoning_effort: 'low',
    )
  end

  it 'allows a legitimate narrowing question in the same broad branch' do
    allow(OpenaiClient).to receive(:call)

    narrowing_result = described_class.call(
      query: query,
      effective_query: effective_query,
      answers: [
        {
          question: 'Which best describes the item being imported?',
          answer: 'Another part or accessory for electrical measuring/checking instruments',
        },
      ],
      candidate_question: {
        question: 'Which type of accessory is being imported?',
        options: [
          'Probe or test lead',
          'Connector',
          'Carrying case',
          'Calibration component',
        ],
      },
      request_id: request_id,
      attempt_number: 2,
    )

    expect(narrowing_result).to be_allowed
    expect(narrowing_result).not_to be_duplicate
    expect(narrowing_result.reason).to eq('not_suspicious')
    expect(OpenaiClient).not_to have_received(:call)
  end

  it 'allows the candidate without calling the validator when the guard is disabled' do
    AdminConfiguration.where(name: 'interactive_search_duplicate_question_guard_enabled').first.update(value: Sequel.pg_jsonb_wrap(false))
    allow(OpenaiClient).to receive(:call)

    expect(result).to be_allowed
    expect(result.suspicious).to be(false)
    expect(OpenaiClient).not_to have_received(:call)
  end

  it 'allows suspicious candidates when the validator response is malformed' do
    allow(OpenaiClient).to receive(:call).and_return('not json')

    expect(result).to be_allowed
    expect(result.suspicious).to be(true)
    expect(result.reason).to eq('validator_unparseable')
  end

  it 'uses the configured validator prompt with substituted JSON context' do
    AdminConfiguration.where(name: 'interactive_search_duplicate_question_guard_context')
      .first
      .update(value: Sequel.pg_jsonb_wrap('Custom validator prompt %{search_query} %{effective_query} %{previous_answers} %{candidate_question}'))
    allow(OpenaiClient).to receive(:call).and_return(
      '{"duplicate": true, "reason": "Configured prompt used", "new_dimension": null}',
    )

    result

    expect(OpenaiClient).to have_received(:call).with(
      a_string_including(
        'Custom validator prompt',
        query,
        effective_query,
        '"question":"What best describes the goods being imported?"',
        '"question":"Which of these best matches the item being imported?"',
        '"options":["A digital multimeter instrument"',
      ),
      model: 'gpt-5-nano-2025-08-07',
      reasoning_effort: 'low',
    )
  end

  it 'rejects an exact repeated question even when options do not repeat the selected answer' do
    allow(OpenaiClient).to receive(:call).and_return(
      '{"duplicate": true, "reason": "Same question text as an earlier question", "new_dimension": null}',
    )

    repeated_question_result = described_class.call(
      query: 'Leather handbag with shoulder strap',
      effective_query: 'Leather handbag with shoulder strap',
      answers: [
        {
          question: 'What is the outer material?',
          answer: 'Leather',
        },
      ],
      candidate_question: {
        question: 'What is the outer material?',
        options: [
          'Plastic sheeting',
          'Textile material',
          'Composition leather',
        ],
      },
      request_id: request_id,
      attempt_number: 2,
    )

    expect(repeated_question_result).not_to be_allowed
    expect(repeated_question_result.signals).to include('repeated_question_text')
  end

  it 'rejects a reworded broad item-identity question even when options are reworded' do
    allow(OpenaiClient).to receive(:call).and_return(
      '{"duplicate": true, "reason": "Reworded broad item-identity question", "new_dimension": null}',
    )

    reworded_result = described_class.call(
      query: query,
      effective_query: effective_query,
      answers: [
        {
          question: 'Which best describes the goods being imported?',
          answer: 'Electrical testing accessory',
        },
      ],
      candidate_question: {
        question: 'Which of these best matches the imported item?',
        options: [
          'Meter probe set',
          'Insulated connector lead',
          'Testing cable kit',
        ],
      },
      request_id: request_id,
      attempt_number: 2,
    )

    expect(reworded_result).not_to be_allowed
    expect(reworded_result.signals).to include('broad_item_identity_stem')
  end

  it 'rejects a reworded category-style item-identity question' do
    allow(OpenaiClient).to receive(:call).and_return(
      '{"duplicate": true, "reason": "Reworded item category question", "new_dimension": null}',
    )

    category_result = described_class.call(
      query: query,
      effective_query: effective_query,
      answers: [
        {
          question: 'What type of goods are these?',
          answer: 'Electrical testing accessory',
        },
      ],
      candidate_question: {
        question: 'Which category does this item fall into?',
        options: [
          'Meter probe set',
          'Insulated connector lead',
          'Testing cable kit',
        ],
      },
      request_id: request_id,
      attempt_number: 2,
    )

    expect(category_result).not_to be_allowed
    expect(category_result.signals).to include('broad_item_identity_stem')
  end

  it 'rejects a short repeated question after stop-word normalization' do
    allow(OpenaiClient).to receive(:call).and_return(
      '{"duplicate": true, "reason": "Same material distinction", "new_dimension": null}',
    )

    short_question_result = described_class.call(
      query: 'Leather handbag with shoulder strap',
      effective_query: 'Leather handbag with shoulder strap',
      answers: [
        {
          question: 'What material?',
          answer: 'Leather',
        },
      ],
      candidate_question: {
        question: 'Material?',
        options: [
          'Plastic',
          'Textile',
          'Composition leather',
        ],
      },
      request_id: request_id,
      attempt_number: 2,
    )

    expect(short_question_result).not_to be_allowed
    expect(short_question_result.signals).to include('similar_question_text')
  end

  it 'rejects a short subset repeated question after stop-word normalization' do
    allow(OpenaiClient).to receive(:call).and_return(
      '{"duplicate": true, "reason": "Same material distinction", "new_dimension": null}',
    )

    short_question_result = described_class.call(
      query: 'Leather handbag with shoulder strap',
      effective_query: 'Leather handbag with shoulder strap',
      answers: [
        {
          question: 'What outer material?',
          answer: 'Leather',
        },
      ],
      candidate_question: {
        question: 'Material?',
        options: [
          'Plastic',
          'Textile',
          'Composition leather',
        ],
      },
      request_id: request_id,
      attempt_number: 2,
    )

    expect(short_question_result).not_to be_allowed
    expect(short_question_result.signals).to include('similar_question_text')
  end

  it 'allows suspicious candidates without logging a full search failure when the validator raises' do
    allow(OpenaiClient).to receive(:call).and_raise(Faraday::TimeoutError)
    allow(Search::Instrumentation).to receive(:search_failed)

    expect(result).to be_allowed
    expect(result.suspicious).to be(true)
    expect(result.reason).to eq('validator_unparseable')
    expect(Search::Instrumentation).not_to have_received(:search_failed)
  end

  it 'allows continuation questions whose options include the previous other-like answer' do
    allow(OpenaiClient).to receive(:call).and_return(
      '{"duplicate": false, "reason": "Uses the previous catch-all branch as a continuation option", "new_dimension": "accessory type"}',
    )

    continuation_result = described_class.call(
      query: query,
      effective_query: effective_query,
      answers: [
        {
          question: 'Which best describes the item being imported?',
          answer: 'Another part or accessory for electrical measuring/checking instruments',
        },
      ],
      candidate_question: {
        question: 'Which type of accessory is being imported?',
        options: [
          'Probe or test lead',
          'Connector',
          'Carrying case',
          'Another part or accessory for electrical measuring/checking instruments',
        ],
      },
      request_id: request_id,
      attempt_number: 2,
    )

    expect(continuation_result).to be_allowed
    expect(continuation_result.suspicious).to be(true)
    expect(continuation_result.reason).to eq('Uses the previous catch-all branch as a continuation option')
  end

  describe 'labelled fixture corpus routing' do
    let(:duplicate_question_texts) do
      duplicate_question_fixtures.map { |fixture| fixture[:candidate_question][:question] }.to_set
    end
    let(:corpus) do
      duplicate_question_fixtures +
        continuation_question_fixtures +
        close_new_question_fixtures +
        new_question_fixtures
    end

    before do
      allow(OpenaiClient).to receive(:call) do |prompt, **|
        candidate_question_json = prompt.match(/Candidate question JSON:\n(?<json>\{[^\n]*\})/)[:json]
        candidate_question = JSON.parse(candidate_question_json)
        duplicate = duplicate_question_texts.include?(candidate_question['question'])
        {
          duplicate: duplicate,
          reason: duplicate ? 'Repeats a previous classification distinction' : 'Asks a new classification dimension',
          new_dimension: duplicate ? nil : 'fixture dimension',
        }.to_json
      end
    end

    it 'classifies duplicates, continuation options, close new questions, and new questions correctly' do
      results = corpus.map do |fixture|
        fixture.merge(
          result: described_class.call(
            query: fixture[:query],
            effective_query: fixture[:effective_query],
            answers: fixture[:answers],
            candidate_question: fixture[:candidate_question],
            request_id: "fixture-#{fixture[:id]}",
            attempt_number: fixture[:answers].size + 1,
          ),
        )
      end

      aggregate_failures 'fixture corpus' do
        expect(results.size).to eq(1_000)
        expect(results.count { |fixture| fixture[:expected_duplicate] }).to eq(250)
        expect(results.count { |fixture| fixture[:category] == :continuation }).to eq(250)
        expect(results.count { |fixture| fixture[:category] == :close_new }).to eq(250)
        expect(results.count { |fixture| fixture[:category] == :new_question }).to eq(250)
        expect(results.select { |fixture| fixture[:category] == :continuation }.map { |fixture| fixture[:result].suspicious }).to all(be(true))
        expect(results.count { |fixture| fixture[:category] == :close_new && fixture[:result].suspicious }).to eq(125)
        expect(results.select { |fixture| fixture[:category] == :new_question }.map { |fixture| fixture[:result].suspicious }).to all(be(false))
        expect(OpenaiClient).to have_received(:call).exactly(625).times

        results.each do |fixture|
          result = fixture[:result]
          failure_label = "#{fixture[:id]} #{fixture[:category]} #{fixture[:candidate_question][:question]}"

          expect(result.duplicate?).to eq(fixture[:expected_duplicate]), failure_label
          expect(result.allowed?).to eq(!fixture[:expected_duplicate]), failure_label
        end
      end
    end
  end

  def duplicate_question_fixtures
    broad_answers = ['Another electrical measuring or checking instrument', 'Other measuring or checking appliance', 'Another part or accessory for electrical measuring instruments', 'Other apparatus for testing electrical quantities', 'Another instrument for checking voltage or current']

    Array.new(250) do |index|
      selected_answer = broad_answers[index % broad_answers.size]
      fixture("duplicate-#{index}", :duplicate, true, "Digital multimeter probe lead set fixture #{index}", "Digital multimeter probe lead set fixture #{index} #{selected_answer}", [['What best describes the goods being imported?', selected_answer], ['Which of these best describes what is actually included in the imported product?', selected_answer]], "Which of these best matches the item being imported? #{index}", ['A digital multimeter instrument', 'A pair of multimeter test leads/probes with connectors', selected_answer, 'An insulated electrical cable with connectors'])
    end
  end

  def continuation_question_fixtures
    dimensions = [
      ['Which type of accessory is being imported?', %w[Probe Connector Case Adapter]],
      ['What is the accessory primarily designed to connect to?', ['A multimeter', 'An oscilloscope', 'A calibration bench', 'A power supply']],
      ['Which connection format is present on the lead?', ['Banana plug', 'Crocodile clip', 'Needle probe', 'Ring terminal']],
      ['What insulation rating is stated for the accessory?', ['Up to 300 V', 'Up to 600 V', 'Up to 1000 V', 'No stated rating']],
      ['Is the product imported as a replacement lead or a complete instrument?', ['Replacement lead', 'Complete instrument', 'Retail kit containing both']],
    ]

    Array.new(250) do |index|
      question, options = dimensions[index % dimensions.size]
      selected_answer = 'Another part or accessory for electrical measuring/checking instruments'
      fixture("continuation-#{index}", :continuation, false, "Electrical test lead accessory fixture #{index}", "Electrical test lead accessory fixture #{index} #{selected_answer}", [['Which best describes the item being imported?', selected_answer], ['Which broad branch does it belong to?', selected_answer]], "#{question} #{index}", options + [selected_answer])
    end
  end

  def close_new_question_fixtures
    stems = ['Which measuring instrument is the accessory specifically for?', 'Which electrical quantity is the item designed to help measure?', 'What physical form does the measuring accessory take?', 'Which safety category is printed on the checking instrument accessory?', 'Which part of the electrical testing setup does the item replace?']

    Array.new(250) do |index|
      selected_answer = 'Another electrical measuring or checking instrument'
      options = %w[Multimeter Oscilloscope] + ['Voltage tester', 'Continuity tester']
      options << selected_answer if index.even?

      fixture("close-new-#{index}", :close_new, false, "Electrical measuring checking probe fixture #{index}", "Electrical measuring checking probe fixture #{index} #{selected_answer}", [['What best describes the goods being imported?', selected_answer]], "#{stems[index % stems.size]} #{index}", options)
    end
  end

  def new_question_fixtures
    stems = ['What material is the outer sheath made from?', 'How many leads are included in the retail package?', 'Is the product fitted with connectors at both ends?', 'What is the maximum stated current rating?', 'Is the product supplied on a reel or as individual leads?']

    Array.new(250) do |index|
      fixture("new-question-#{index}", :new_question, false, "Cable connector testing fixture #{index}", "Cable connector testing fixture #{index}", [['What best describes the goods being imported?', 'Electrical cable with connectors']], "#{stems[index % stems.size]} #{index}", ['Yes', 'No', 'Not stated', 'Not applicable'])
    end
  end

  def fixture(id, category, expected_duplicate, query, effective_query, answers, question, options)
    { id:, category:, expected_duplicate:, query:, effective_query:, answers: answers.map { |qa| { question: qa.first, answer: qa.second } }, candidate_question: { question:, options: } }
  end
end
