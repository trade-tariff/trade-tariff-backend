RSpec.describe TariffKnowledge::SemanticRuleFactValidator do
  describe '.call' do
    let(:source_text) { 'Chapter 01 includes Heading 0101 covers live horses.' }
    let(:valid_fact) do
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

    it 'keeps schema-valid facts with exact source spans' do
      facts = described_class.call(
        facts: [valid_fact],
        source_text:,
        valid_references: [
          { 'type' => 'chapter', 'code' => '01' },
          { 'type' => 'heading', 'code' => '0101' },
        ],
      )

      expect(facts).to contain_exactly(
        include(
          'source_span' => 'Heading 0101 covers live horses.',
          'relationship_type' => 'includes',
          'target' => { 'type' => 'heading', 'code' => '0101' },
        ),
      )
    end

    it 'rejects facts that are malformed or not source backed' do
      facts = described_class.call(
        facts: [
          nil,
          'not a hash',
          valid_fact.merge('source_span' => 'not present in source'),
          valid_fact.merge('source_reference' => ''),
          valid_fact.merge('relationship_type' => 'maybe'),
          valid_fact.merge('subject' => 'not a hash'),
          valid_fact.merge('subject' => { 'type' => 'commodity', 'code' => '9999999999' }),
          valid_fact.merge('target' => 'not a hash'),
          valid_fact.merge('target' => { 'type' => 'heading', 'code' => '9999' }),
          valid_fact.merge('conditions' => 'invented condition'),
          valid_fact.merge('conditions' => [123]),
          valid_fact.merge('exceptions' => 'invented exception'),
        ],
        source_text:,
        valid_references: [
          'not a hash',
          { 'type' => 'chapter', 'code' => '01' },
          { 'type' => 'heading', 'code' => '0101' },
        ],
      )

      expect(facts).to be_empty
    end

    it 'rejects a single malformed fact object without raising' do
      facts = described_class.call(
        facts: 'not a hash',
        source_text:,
        valid_references: [
          { 'type' => 'chapter', 'code' => '01' },
          { 'type' => 'heading', 'code' => '0101' },
        ],
      )

      expect(facts).to be_empty
    end

    it 'rejects low-confidence facts from automatic context' do
      facts = described_class.call(
        facts: [valid_fact.merge('confidence' => 'low')],
        source_text:,
        valid_references: [
          { 'type' => 'chapter', 'code' => '01' },
          { 'type' => 'heading', 'code' => '0101' },
        ],
      )

      expect(facts).to be_empty
    end

    it 'requires targets to be deterministic candidate targets when supplied' do
      facts = described_class.call(
        facts: [
          valid_fact.merge(
            'target' => { 'type' => 'chapter', 'code' => '01' },
            'source_span' => 'Chapter 01 includes',
          ),
          valid_fact,
        ],
        source_text:,
        valid_references: [
          { 'type' => 'chapter', 'code' => '01' },
          { 'type' => 'heading', 'code' => '0101' },
        ],
        target_references: [{ 'type' => 'heading', 'code' => '0101' }],
      )

      expect(facts).to contain_exactly(include('target' => { 'type' => 'heading', 'code' => '0101' }))
    end

    it 'accepts section source references as deterministic subjects' do
      fact = valid_fact.merge(
        'source_reference' => 'Section 1 note 1',
        'subject' => { 'type' => 'section', 'code' => '1' },
      )

      facts = described_class.call(
        facts: [fact],
        source_text:,
        valid_references: [
          { 'type' => 'section', 'code' => '1' },
          { 'type' => 'heading', 'code' => '0101' },
        ],
        target_references: [{ 'type' => 'heading', 'code' => '0101' }],
      )

      expect(facts).to contain_exactly(include('subject' => { 'type' => 'section', 'code' => '1' }))
    end
  end
end
