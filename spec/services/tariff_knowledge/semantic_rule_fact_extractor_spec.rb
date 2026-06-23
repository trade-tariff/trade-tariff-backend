RSpec.describe TariffKnowledge::SemanticRuleFactExtractor do
  describe '.call' do
    let(:fragment_node) do
      create(
        :tariff_knowledge_node,
        :note_fragment,
        content: 'Heading 0101 covers live horses.',
        source_type: 'customs_tariff_chapter_note',
        source_id: '01',
      )
    end
    let(:source_reference) { { 'type' => 'chapter', 'code' => '01' } }
    let(:candidate_references) { [{ 'type' => 'heading', 'code' => '0101' }] }
    let(:accepted_fact) do
      {
        'source_reference' => 'Chapter 01 note 1',
        'source_span' => 'Heading 0101 covers live horses.',
        'relationship_type' => 'includes',
        'subject' => { 'type' => 'chapter', 'code' => '01' },
        'target' => { 'type' => 'heading', 'code' => '0101' },
        'conditions' => ['live horses'],
        'exceptions' => [],
        'confidence' => 'high',
      }
    end

    before do
      allow(OpenaiClient).to receive(:call).and_return(
        'facts' => [
          accepted_fact,
          accepted_fact.merge('source_span' => 'not in source'),
          accepted_fact.merge('target' => { 'type' => 'chapter', 'code' => '01' }),
        ],
      )
    end

    it 'persists validated source-backed facts' do
      facts = described_class.call(fragment_node:, source_reference:, candidate_references:)

      expect(facts).to contain_exactly(include('source_span' => 'Heading 0101 covers live horses.'))
      expect(fragment_node.refresh.metadata.to_h['semantic_rule_facts'])
        .to contain_exactly(include('source_span' => 'Heading 0101 covers live horses.'))
    end

    it 'prompts for candidate connection evaluation within deterministic bounds' do
      described_class.call(fragment_node:, source_reference:, candidate_references:)

      expect(OpenaiClient).to have_received(:call) do |context, **_options|
        expect(context).to include('source_span')
        expect(context).to include('relationship_type')
        expect(context).to include('conditions')
        expect(context).to include('Evaluate only these deterministic candidate target references')
        expect(context).to include('"type": "heading"')
        expect(context).to include('"code": "0101"')
        expect(context).to include('Return JSON')
      end
    end

    it 'rejects malformed extractor responses without raising' do
      allow(OpenaiClient).to receive(:call).and_return('not json')

      facts = described_class.call(fragment_node:, source_reference:, candidate_references:)

      expect(facts).to be_empty
      expect(fragment_node.refresh.metadata.to_h['semantic_rule_facts']).to be_empty
    end

    it 'rejects top-level array responses without raising' do
      allow(OpenaiClient).to receive(:call).and_return([{ 'facts' => [accepted_fact] }])

      facts = described_class.call(fragment_node:, source_reference:, candidate_references:)

      expect(facts).to be_empty
      expect(fragment_node.refresh.metadata.to_h['semantic_rule_facts']).to be_empty
    end

    it 'rejects non-array fact payloads without raising' do
      allow(OpenaiClient).to receive(:call).and_return(
        'facts' => accepted_fact,
      )

      facts = described_class.call(fragment_node:, source_reference:, candidate_references:)

      expect(facts).to be_empty
      expect(fragment_node.refresh.metadata.to_h['semantic_rule_facts']).to be_empty
    end
  end
end
