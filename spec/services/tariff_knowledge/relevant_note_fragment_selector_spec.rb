RSpec.describe TariffKnowledge::RelevantNoteFragmentSelector do
  let(:search_result_class) { Data.define(:goods_nomenclature_item_id, :description, :full_description, :score) }
  let(:search_results) do
    [
      search_result_class.new(
        goods_nomenclature_item_id: '9506911000',
        description: 'Exercising apparatus with adjustable resistance mechanisms',
        full_description: nil,
        score: 10,
      ),
      search_result_class.new(
        goods_nomenclature_item_id: '6403999110',
        description: 'Sports footwear with outer soles of rubber',
        full_description: nil,
        score: 6,
      ),
    ]
  end
  let(:query) { 'children exercise stepper with adjustable resistance' }
  let(:note_content) { 'Full Chapter 95 note content should not be emitted by the selector.' }
  let(:context_hash) { Digest::SHA256.hexdigest(note_content) }
  let(:note) do
    create(
      :tariff_knowledge_compressed_note,
      goods_nomenclature_item_id: '9506911000',
      content: note_content,
      context_hash:,
      metadata: Sequel.pg_jsonb_wrap(
        'evidence' => [
          evidence_for(
            'note_fragment:customs_tariff_chapter_note:1.31:95:0002',
            'candles (heading 3406);',
            'exclusion',
          ),
          evidence_for(
            'note_fragment:customs_tariff_chapter_note:1.31:95:0008',
            'sports footwear (other than skating boots with ice or roller skates attached) of Chapter 64',
            'exclusion',
          ),
          evidence_for(
            'note_fragment:customs_tariff_chapter_note:1.31:95:0032',
            'Heading 9506 includes articles and equipment for general physical exercise',
            'inclusion',
            range_type: 'heading',
            range_code: '9506',
          ),
        ],
      ),
    )
  end

  before do
    create_fragment('note_fragment:customs_tariff_chapter_note:1.31:95:0002', 'candles (heading 3406);')
    create_fragment(
      'note_fragment:customs_tariff_chapter_note:1.31:95:0008',
      'sports footwear (other than skating boots with ice or roller skates attached) of Chapter 64',
    )
    create_fragment(
      'note_fragment:customs_tariff_chapter_note:1.31:95:0032',
      'Heading 9506 includes articles and equipment for general physical exercise',
    )
  end

  it 'selects fragments that discriminate between retrieved candidate ranges' do
    contexts = described_class.call(
      query:,
      search_results:,
      notes_by_item_id: { '9506911000' => note },
    )

    expect(contexts.size).to eq(1)
    fragment_texts = contexts.first[:fragments].pluck(:text)
    expect(fragment_texts).to include(
      a_string_including('sports footwear'),
      a_string_including('general physical exercise'),
    )
    expect(fragment_texts).not_to include(a_string_including('candles'))
  end

  it 'does not emit full compressed note content' do
    contexts = described_class.call(
      query:,
      search_results:,
      notes_by_item_id: { '9506911000' => note },
    )

    emitted_text = contexts.first[:fragments].pluck(:text).join("\n")
    expect(emitted_text).not_to include(note_content)
  end

  it 'uses range metadata even when context text does not repeat the candidate code' do
    range_note = create_note_with_evidence(
      '9506911000',
      evidence_for(
        'note_fragment:customs_tariff_chapter_note:1.31:95:range',
        'This includes articles and equipment for general physical exercise.',
        'reference',
        range_type: 'heading',
        range_code: '9506',
      ),
    )
    create_fragment(
      'note_fragment:customs_tariff_chapter_note:1.31:95:range',
      'This includes articles and equipment for general physical exercise.',
    )

    contexts = described_class.call(
      query: 'unrelated query',
      search_results: [
        search_result_class.new(
          goods_nomenclature_item_id: '9506911000',
          description: 'Articles and equipment for general physical exercise',
          full_description: nil,
          score: 10,
        ),
      ],
      notes_by_item_id: { '9506911000' => range_note },
    )

    expect(contexts.first[:fragments].first[:why_relevant]).to include('references retrieved heading 9506')
  end

  it 'caps total emitted fragments across all selected notes' do
    contexts = described_class.call(
      query: 'plastic exercise article',
      search_results: Array.new(5) do |index|
        search_result_class.new(
          goods_nomenclature_item_id: "95069110#{index.to_s.rjust(2, '0')}",
          description: 'Articles and equipment for general physical exercise',
          full_description: nil,
          score: 10,
        )
      end,
      notes_by_item_id: 5.times.to_h do |note_index|
        item_id = "95069110#{note_index.to_s.rjust(2, '0')}"
        [item_id, create_note_with_fragments(item_id, note_index)]
      end,
    )

    expect(contexts.sum { |context| context[:fragments].size }).to eq(described_class::MAX_TOTAL_FRAGMENTS)
  end

  it 'applies the global fragment cap to the highest scoring notes first' do
    high_score_note = create_note_with_fragments('9506911000', 1)
    low_score_notes = 8.times.to_h do |index|
      item_id = "95069120#{index.to_s.rjust(2, '0')}"
      key = "note_fragment:customs_tariff_chapter_note:1.31:95:low#{index}"
      text = "Chapter 95 includes exercise goods #{index}."
      create_fragment(key, text)
      [item_id, create_note_with_evidence(item_id, evidence_for(key, text, 'inclusion'))]
    end

    contexts = described_class.call(
      query: 'exercise article',
      search_results: [
        search_result_class.new(
          goods_nomenclature_item_id: '9506911000',
          description: 'Articles and equipment for general physical exercise',
          full_description: nil,
          score: 10,
        ),
      ],
      notes_by_item_id: low_score_notes.merge('9506911000' => high_score_note),
    )

    expect(contexts.pluck(:key)).to include(high_score_note.context_hash)
  end

  it 'does not apply the same-chapter bonus to section evidence source ids' do
    section_note = create_note_with_evidence(
      '9506911000',
      evidence_for(
        'note_fragment:customs_tariff_section_note:1.31:95:0001',
        'This section excludes exercise goods.',
        'exclusion',
        source_type: 'customs_tariff_section_note',
      ),
    )
    create_fragment('note_fragment:customs_tariff_section_note:1.31:95:0001', 'This section excludes exercise goods.')

    contexts = described_class.call(
      query:,
      search_results:,
      notes_by_item_id: { '9506911000' => section_note },
    )

    expect(contexts).to be_empty
  end

  def evidence_for(key, text, context_type, range_type: nil, range_code: nil, source_type: 'customs_tariff_chapter_note')
    {
      'source_node_key' => key,
      'source_type' => source_type,
      'source_id' => '95',
      'source_title' => key.split(':').last,
      'source_context' => text,
      'context_type' => context_type,
      'range_type' => range_type,
      'range_code' => range_code,
      'relationships' => [TariffKnowledge::Edge::APPLIES_TO],
    }
  end

  def create_note_with_fragments(item_id, note_index)
    evidence = Array.new(6) do |fragment_index|
      key = "note_fragment:customs_tariff_chapter_note:1.31:95:#{note_index}#{fragment_index}"
      text = "Heading 9506 includes plastic exercise article #{note_index}-#{fragment_index}"
      create_fragment(key, text)
      evidence_for(key, text, 'inclusion', range_type: 'heading', range_code: '9506')
    end
    content = "compressed note #{note_index}"

    create(
      :tariff_knowledge_compressed_note,
      goods_nomenclature_item_id: item_id,
      content:,
      context_hash: Digest::SHA256.hexdigest(content),
      metadata: Sequel.pg_jsonb_wrap('evidence' => evidence),
    )
  end

  def create_note_with_evidence(item_id, evidence)
    content = "compressed note #{item_id}"

    create(
      :tariff_knowledge_compressed_note,
      goods_nomenclature_item_id: item_id,
      content:,
      context_hash: Digest::SHA256.hexdigest(content),
      metadata: Sequel.pg_jsonb_wrap('evidence' => [evidence]),
    )
  end

  def create_fragment(key, content)
    _node_type, source_type, _version, source_id, _sequence = key.split(':')

    create(
      :tariff_knowledge_node,
      :note_fragment,
      key:,
      content:,
      source_type:,
      source_id:,
    )
  end
end
