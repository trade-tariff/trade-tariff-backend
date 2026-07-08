RSpec.describe TariffKnowledge::PublicAtarFactGenerator do
  subject(:facts) { described_class.call(ruling, ai_client:) }

  let(:ai_client) { instance_double(OpenaiClient) }
  let(:ruling) do
    build(
      :tariff_knowledge_public_atar_ruling,
      ref: '600014988',
      commodity_code: '1008290000',
      goods_nomenclature_item_id: '1008290000',
      description: 'A heating pad filled with millet grains and covered with cotton textile material. It is worn next to the body for heat treatment.',
      keywords: Sequel.pg_array(['MILLET', 'HEATING PADS', 'OF COTTON'], :text),
      justification: 'Classification has been determined in accordance with GIR 1 and GIR 6.',
    )
  end

  before do
    create(
      :admin_configuration,
      :nested_options,
      name: 'atar_fact_model',
      area: 'classification',
      value: {
        'selected' => 'gpt-5.5',
        'sub_values' => { 'reasoning_effort' => 'high' },
        'options' => [
          { 'key' => 'gpt-5.5', 'label' => 'GPT-5.5', 'sub_options' => { 'reasoning_effort' => %w[none low medium high xhigh] } },
        ],
      },
    )
    create(:admin_configuration, :markdown, name: 'atar_fact_context', area: 'classification', value: 'Custom ATAR fact prompt')
    allow(ai_client).to receive(:call).and_return(
      'facts' => [
        'microwaveable body warmer',
        { 'value' => 'cotton textile cover' },
        { 'value' => 'GIR 1' },
        { 'value' => 123 },
        { 'value' => 'heating pads' },
        { 'value' => 'third generation double angular contact flanged hub unit' },
        { 'value' => '' },
      ],
    )
  end

  it 'returns concise classification facts from the AI response' do
    expect(facts).to eq(['microwaveable body warmer', 'cotton textile cover'])
  end

  it 'filters unusable facts before returning valid later facts' do
    allow(ai_client).to receive(:call).and_return(
      'facts' => [
        { 'value' => nil },
        { 'value' => 123 },
        { 'value' => 'GIR 1' },
        { 'value' => 'heating pads' },
        'microwaveable body warmer',
      ],
    )

    expect(facts).to eq(['microwaveable body warmer'])
  end

  it 'returns an empty list when every returned fact is unusable' do
    allow(ai_client).to receive(:call).and_return(
      'facts' => [
        { 'value' => nil },
        { 'value' => 123 },
        { 'value' => 'GIR 1' },
        { 'value' => 'heating pads' },
        { 'value' => 'third generation double angular contact flanged hub unit' },
      ],
    )

    expect(facts).to eq([])
  end

  it 'sends the ATAR context to the configured model with high reasoning' do
    facts

    expect(ai_client).to have_received(:call).with(
      array_including(
        hash_including(role: 'system', content: 'Custom ATAR fact prompt'),
        hash_including(role: 'user', content: a_string_including('600014988', 'heating pad', 'MILLET')),
      ),
      model: 'gpt-5.5',
      reasoning_effort: 'high',
    )
  end

  it 'returns nil when fact generation fails so imports can preserve existing facts' do
    allow(ai_client).to receive(:call).and_raise(OpenaiClient::ApiError.new(status: 500, body: 'nope'))
    allow(Rails.logger).to receive(:warn)

    expect(facts).to be_nil
    expect(Rails.logger).to have_received(:warn).with(/Public ATAR fact generation failed for ATAR 600014988/)
    expect(Rails.logger).to have_received(:warn).with(/status=500/)
    expect(Rails.logger).not_to have_received(:warn).with(/nope/)
  end

  it 'returns nil when the AI response does not include a facts payload' do
    allow(ai_client).to receive(:call).and_return('not json')

    expect(facts).to be_nil
  end
end
