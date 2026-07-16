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

  it 'explains selected and omitted evidence without changing the prompt contexts' do
    selection = described_class.call_with_diagnostics(
      query:,
      search_results:,
      notes_by_item_id: { '9506911000' => note },
    )

    expect(selection.contexts).to eq(
      described_class.call(
        query:,
        search_results:,
        notes_by_item_id: { '9506911000' => note },
      ),
    )
    expect(selection.diagnostics).to include(
      status: 'selected',
      considered_note_count: 1,
      considered_evidence_count: 3,
      selected_note_count: 1,
      selected_evidence_count: 2,
      omitted_evidence_count: 1,
      omitted_evidence_truncated: false,
      limits: {
        minimum_score: described_class::MIN_SCORE,
        per_note: described_class::MAX_FRAGMENTS_PER_NOTE,
        total: described_class::MAX_TOTAL_FRAGMENTS,
      },
    )

    selected = selection.diagnostics[:selected_contexts].first
    expect(selected).to include(
      context_hash: context_hash,
      commodity_codes: %w[9506911000],
    )
    expect(selected[:evidence]).to all(include(
                                         :source_node_key,
                                         :source_type,
                                         :source_id,
                                         :source_version,
                                         :score,
                                         :score_reasons,
                                         :graph_paths,
                                         decision: 'selected',
                                       ))
    expect(selected[:evidence].pluck(:text)).to contain_exactly(
      a_string_including('sports footwear'),
      a_string_including('general physical exercise'),
    )

    omitted = selection.diagnostics[:omitted_evidence].sole
    expect(omitted).to include(
      context_hash: context_hash,
      source_node_key: 'note_fragment:customs_tariff_chapter_note:1.31:95:0002',
      decision: 'omitted',
      omission_reason: 'below_minimum_score',
    )
  end

  it 'distinguishes absent compressed notes from ineligible evidence' do
    absent = described_class.call_with_diagnostics(
      query:,
      search_results:,
      notes_by_item_id: {},
    )
    ineligible = described_class.call_with_diagnostics(
      query:,
      search_results:,
      notes_by_item_id: { '9506911000' => create_note_with_evidence('9506911000', evidence_for('note_fragment:customs_tariff_chapter_note:1.31:95:0999', 'Candles only.', 'reference')) },
    )

    expect(absent.diagnostics[:status]).to eq('no_compressed_notes')
    expect(ineligible.diagnostics[:status]).to eq('no_eligible_evidence')
  end

  it 'reports equal-score context duplicates accurately' do
    shared_evidence = evidence_for(
      'note_fragment:customs_tariff_chapter_note:1.31:95:0032',
      'Heading 9506 includes articles and equipment for general physical exercise',
      'inclusion',
      range_type: 'heading',
      range_code: '9506',
    )
    first_note = create_note_with_evidence('9506911000', shared_evidence)
    second_note = create_note_with_evidence('6403999110', shared_evidence).tap do |duplicate|
      duplicate.update(context_hash: first_note.context_hash)
    end

    selection = described_class.call_with_diagnostics(
      query:,
      search_results:,
      notes_by_item_id: { '9506911000' => first_note, '6403999110' => second_note },
    )

    expect(selection.diagnostics[:omitted_evidence]).to include(
      include(
        source_node_key: shared_evidence['source_node_key'],
        omission_reason: 'duplicate_same_score',
      ),
    )
  end

  it 'bounds block fragment keys in diagnostics' do
    block_note = create(
      :tariff_knowledge_compressed_note,
      goods_nomenclature_item_id: '7201200000',
      content: 'compressed note bounded block keys',
      metadata: Sequel.pg_jsonb_wrap(
        'evidence_blocks' => [
          {
            'source_node_key' => 'note_block:customs_tariff_chapter_note:1.31:72:1:a',
            'source_title' => 'pig iron',
            'source_context' => 'pig iron means iron-carbon alloys containing more than 2% carbon.',
            'block_type' => 'definition',
            'term' => 'pig iron',
            'source_type' => 'customs_tariff_chapter_note',
            'source_id' => '72',
            'source_version' => '1.31',
            'fragment_node_keys' => Array.new(25) { |index| "fragment-#{index}" },
          },
        ],
      ),
    )

    selection = described_class.call_with_diagnostics(
      query: 'pig iron',
      search_results: [
        search_result_class.new(
          goods_nomenclature_item_id: '7201200000',
          description: 'Non-alloy pig iron',
          full_description: nil,
          score: 10,
        ),
      ],
      notes_by_item_id: { '7201200000' => block_note },
    )
    evidence = selection.diagnostics.dig(:selected_contexts, 0, :evidence, 0)

    expect(evidence[:fragment_node_keys].size).to eq(described_class::MAX_LOGGED_FRAGMENT_NODE_KEYS)
    expect(evidence[:fragment_node_keys_truncated]).to be(true)
  end

  it 'bounds omitted evidence while retaining samples from each omission reason' do
    below_minimum = Array.new(25) do |index|
      evidence_for(
        "note_fragment:customs_tariff_chapter_note:1.31:95:low#{index}",
        "Candles only #{index}.",
        'reference',
      )
    end
    eligible = Array.new(3) do |index|
      evidence_for(
        "note_fragment:customs_tariff_chapter_note:1.31:95:eligible#{index}",
        "Heading 9506 includes exercise articles #{index}.",
        'inclusion',
        range_type: 'heading',
        range_code: '9506',
      )
    end
    note = create(
      :tariff_knowledge_compressed_note,
      goods_nomenclature_item_id: '9506911000',
      content: 'compressed note with many omissions',
      metadata: Sequel.pg_jsonb_wrap('evidence' => below_minimum + eligible),
    )

    selection = described_class.call_with_diagnostics(
      query:,
      search_results:,
      notes_by_item_id: { '9506911000' => note },
    )

    expect(selection.diagnostics).to include(
      omitted_evidence_count: 26,
      logged_omitted_evidence_count: described_class::MAX_LOGGED_OMITTED_EVIDENCE,
      omitted_evidence_truncated: true,
    )
    expect(selection.diagnostics[:omitted_evidence].pluck(:omission_reason)).to include(
      'below_minimum_score',
      'per_note_limit',
    )
  end

  it 'prefers exact query definition blocks over generic chapter exclusions' do
    pig_iron_note = create(
      :tariff_knowledge_compressed_note,
      goods_nomenclature_item_id: '7201200000',
      content: 'compressed note 7201200000',
      context_hash: Digest::SHA256.hexdigest('compressed note 7201200000'),
      metadata: Sequel.pg_jsonb_wrap(
        'evidence_blocks' => [
          {
            'source_node_key' => 'note_block:customs_tariff_chapter_note:1.31:72:1:a',
            'source_title' => 'pig Iron',
            'source_context' => 'pig Iron: Iron-carbon alloys not usefully malleable, containing more than 2 % carbon; not more than 10 % chromium; not more than 6 % manganese.',
            'block_type' => 'definition',
            'term' => 'pig iron',
            'path' => %w[1 a],
            'source_type' => 'customs_tariff_chapter_note',
            'source_id' => '72',
            'source_version' => '1.31',
            'fragment_node_keys' => [],
          },
        ],
        'evidence' => [
          evidence_for(
            'note_fragment:customs_tariff_chapter_note:1.31:72:0069',
            'Chapter 72 does not include products of heading 7301 or 7302.',
            'exclusion',
            source_id: '72',
          ),
        ],
      ),
    )

    contexts = described_class.call(
      query: 'pig iron',
      search_results: [
        search_result_class.new(
          goods_nomenclature_item_id: '7201200000',
          description: 'Non-alloy pig iron in pigs, blocks or other primary forms',
          full_description: nil,
          score: 10,
        ),
      ],
      notes_by_item_id: { '7201200000' => pig_iron_note },
    )

    first_fragment = contexts.first[:fragments].first
    expect(first_fragment[:text]).to include('pig Iron')
    expect(first_fragment[:text]).to include('not more than 10 % chromium')
    expect(first_fragment[:text]).not_to eq('Chapter 72 does not include products of heading 7301 or 7302.')
    expect(first_fragment[:source_ref]).to eq('chapter 72 note')
    expect(first_fragment[:why_relevant]).to include('exact phrase match pig iron')
    expect(first_fragment[:why_relevant].scan(/exact phrase match pig iron/).size).to eq(1)
    expect(first_fragment[:why_relevant]).to include('definition block')
    expect(first_fragment[:why_relevant]).to include('BM25 lexical match pig, iron')
    expect(first_fragment[:score]).to be > described_class::MIN_SCORE
  end

  it 'ranks exact term definition blocks ahead of longer phrase-containing terms' do
    pig_iron_note = create(
      :tariff_knowledge_compressed_note,
      goods_nomenclature_item_id: '7201200000',
      content: 'compressed note pig iron equality',
      context_hash: Digest::SHA256.hexdigest('compressed note pig iron equality'),
      metadata: Sequel.pg_jsonb_wrap(
        'evidence_blocks' => [
          {
            'source_node_key' => 'note_block:customs_tariff_chapter_note:1.31:72:1:a',
            'source_title' => 'pig Iron',
            'source_context' => 'pig Iron: Iron-carbon alloys not usefully malleable, containing more than 2 % carbon; not more than 10 % chromium.',
            'block_type' => 'definition',
            'term' => 'pig iron',
            'source_type' => 'customs_tariff_chapter_note',
            'source_id' => '72',
            'fragment_node_keys' => [],
          },
          {
            'source_node_key' => 'note_block:customs_tariff_chapter_note:1.31:72:1:b',
            'source_title' => 'alloy pig iron',
            'source_context' => 'alloy pig iron: Pig iron containing, by mass, one or more alloy elements in specified proportions.',
            'block_type' => 'definition',
            'term' => 'alloy pig iron',
            'source_type' => 'customs_tariff_chapter_note',
            'source_id' => '72',
            'fragment_node_keys' => [],
          },
        ],
      ),
    )

    contexts = described_class.call(
      query: 'pig iron',
      search_results: [
        search_result_class.new(
          goods_nomenclature_item_id: '7201200000',
          description: 'Non-alloy pig iron in pigs, blocks or other primary forms',
          full_description: nil,
          score: 10,
        ),
      ],
      notes_by_item_id: { '7201200000' => pig_iron_note },
    )

    fragments = contexts.first[:fragments]

    expect(fragments.first[:source]).to eq('pig Iron')
    expect(fragments.second[:source]).to eq('alloy pig iron')
    expect(fragments.first[:why_relevant]).to include('exact term match pig iron')
    expect(fragments.second[:why_relevant]).to include('exact phrase match pig iron in term')
    expect(fragments.second[:why_relevant]).not_to include('exact term match pig iron')
  end

  it 'does not select a compound definition block for a single-word modifier query' do
    pig_iron_note = create(
      :tariff_knowledge_compressed_note,
      goods_nomenclature_item_id: '7201200000',
      content: 'compressed note pig modifier',
      context_hash: Digest::SHA256.hexdigest('compressed note pig modifier'),
      metadata: Sequel.pg_jsonb_wrap(
        'evidence_blocks' => [
          {
            'source_node_key' => 'note_block:customs_tariff_chapter_note:1.31:72:1:a',
            'source_title' => 'pig Iron',
            'source_context' => 'pig Iron: Iron-carbon alloys not usefully malleable.',
            'block_type' => 'definition',
            'term' => 'pig iron',
            'source_type' => 'customs_tariff_chapter_note',
            'source_id' => '72',
            'fragment_node_keys' => [],
          },
        ],
      ),
    )

    contexts = described_class.call(
      query: 'pig',
      search_results: [
        search_result_class.new(
          goods_nomenclature_item_id: '7201200000',
          description: 'Non-alloy pig iron',
          full_description: nil,
          score: 10,
        ),
      ],
      notes_by_item_id: { '7201200000' => pig_iron_note },
    )

    expect(contexts).to be_empty
  end

  it 'does not select an unrelated definition block because aggregate text contains a single-word query' do
    aggregate_note = create(
      :tariff_knowledge_compressed_note,
      goods_nomenclature_item_id: '7201200000',
      content: 'compressed note aggregate pig',
      context_hash: Digest::SHA256.hexdigest('compressed note aggregate pig'),
      metadata: Sequel.pg_jsonb_wrap(
        'evidence_blocks' => [
          {
            'source_node_key' => 'note_block:customs_tariff_chapter_note:1.31:72:1:d',
            'source_title' => 'remelting scrap ingots of iron or steel',
            'source_context' => 'remelting scrap ingots of iron or steel: Parent aggregate text also includes the pig iron definition below it.',
            'block_type' => 'definition',
            'term' => 'remelting scrap ingots of iron or steel',
            'source_type' => 'customs_tariff_chapter_note',
            'source_id' => '72',
            'fragment_node_keys' => [],
          },
        ],
      ),
    )

    contexts = described_class.call(
      query: 'pig',
      search_results: [
        search_result_class.new(
          goods_nomenclature_item_id: '7201200000',
          description: 'Non-alloy pig iron',
          full_description: nil,
          score: 10,
        ),
      ],
      notes_by_item_id: { '7201200000' => aggregate_note },
    )

    expect(contexts).to be_empty
  end

  it 'uses BM25 lexical scoring to rank relevant definition blocks ahead of repeated generic text' do
    lexical_note = create(
      :tariff_knowledge_compressed_note,
      goods_nomenclature_item_id: '7201200000',
      content: 'compressed note lexical pig iron',
      context_hash: Digest::SHA256.hexdigest('compressed note lexical pig iron'),
      metadata: Sequel.pg_jsonb_wrap(
        'evidence_blocks' => [
          {
            'source_node_key' => 'note_block:customs_tariff_chapter_note:1.31:72:1:a',
            'source_title' => 'pig Iron',
            'source_context' => 'pig Iron: Iron-carbon alloys not usefully malleable, containing more than 2 % carbon and cast in pigs, blocks or other primary forms.',
            'block_type' => 'definition',
            'term' => 'pig iron',
            'source_type' => 'customs_tariff_chapter_note',
            'source_id' => '72',
            'fragment_node_keys' => [],
          },
          {
            'source_node_key' => 'note_block:customs_tariff_chapter_note:1.31:72:1:z',
            'source_title' => 'generic chapter 72 exclusions',
            'source_context' => 'Chapter 72 does not include iron articles of heading 7301. Iron articles of heading 7302 are also excluded. Iron waste is handled elsewhere.',
            'block_type' => 'exclusion',
            'term' => nil,
            'source_type' => 'customs_tariff_chapter_note',
            'source_id' => '72',
            'fragment_node_keys' => [],
          },
        ],
      ),
    )

    contexts = described_class.call(
      query: 'pig iron',
      search_results: [
        search_result_class.new(
          goods_nomenclature_item_id: '7201200000',
          description: 'Non-alloy pig iron in pigs, blocks or other primary forms',
          full_description: nil,
          score: 10,
        ),
      ],
      notes_by_item_id: { '7201200000' => lexical_note },
    )

    fragments = contexts.first[:fragments]
    expect(fragments.first[:source]).to eq('pig Iron')
    expect(fragments.first[:why_relevant]).to include('BM25 lexical match pig, iron')
    expect(fragments.second[:source]).to eq('generic chapter 72 exclusions')
  end

  it 'selects a compound definition block for a single-word head-term query' do
    pig_iron_note = create(
      :tariff_knowledge_compressed_note,
      goods_nomenclature_item_id: '7201200000',
      content: 'compressed note iron head',
      context_hash: Digest::SHA256.hexdigest('compressed note iron head'),
      metadata: Sequel.pg_jsonb_wrap(
        'evidence_blocks' => [
          {
            'source_node_key' => 'note_block:customs_tariff_chapter_note:1.31:72:1:a',
            'source_title' => 'pig Iron',
            'source_context' => 'pig Iron: Iron-carbon alloys not usefully malleable.',
            'block_type' => 'definition',
            'term' => 'pig iron',
            'source_type' => 'customs_tariff_chapter_note',
            'source_id' => '72',
            'fragment_node_keys' => [],
          },
        ],
      ),
    )

    contexts = described_class.call(
      query: 'iron',
      search_results: [
        search_result_class.new(
          goods_nomenclature_item_id: '7201200000',
          description: 'Non-alloy pig iron',
          full_description: nil,
          score: 10,
        ),
      ],
      notes_by_item_id: { '7201200000' => pig_iron_note },
    )

    expect(contexts.first[:fragments].first[:source]).to eq('pig Iron')
    expect(contexts.first[:fragments].first[:why_relevant]).to include('exact phrase match iron in term')
  end

  it 'does not award exact phrase score when a single-word query only matches inside a longer word' do
    ironic_note = create(
      :tariff_knowledge_compressed_note,
      goods_nomenclature_item_id: '7201200000',
      content: 'compressed note ironic substring',
      context_hash: Digest::SHA256.hexdigest('compressed note ironic substring'),
      metadata: Sequel.pg_jsonb_wrap(
        'evidence_blocks' => [
          {
            'source_node_key' => 'note_block:customs_tariff_chapter_note:1.31:72:1:z',
            'source_title' => 'ironic',
            'source_context' => 'ironic: A longer word that only contains the query as a substring.',
            'block_type' => 'definition',
            'term' => 'ironic',
            'source_type' => 'customs_tariff_chapter_note',
            'source_id' => '72',
            'fragment_node_keys' => [],
          },
        ],
      ),
    )

    contexts = described_class.call(
      query: 'iron',
      search_results: [
        search_result_class.new(
          goods_nomenclature_item_id: '7201200000',
          description: 'Non-alloy pig iron',
          full_description: nil,
          score: 10,
        ),
      ],
      notes_by_item_id: { '7201200000' => ironic_note },
    )

    why_relevant = contexts.flat_map { |context| context[:fragments] }.map { |fragment| fragment[:why_relevant] }
    expect(why_relevant).not_to include(a_string_including('exact phrase match iron'))

    # Multi-token queries do not suppress block matches, so a prefix phrase such as
    # "iron plate" would still receive EXACT_PHRASE_SCORE against "iron plated" under
    # String#include?. Word-boundary matching rejects that false positive.
    plated_note = create(
      :tariff_knowledge_compressed_note,
      goods_nomenclature_item_id: '7201500000',
      content: 'compressed note iron plated substring',
      context_hash: Digest::SHA256.hexdigest('compressed note iron plated substring'),
      metadata: Sequel.pg_jsonb_wrap(
        'evidence_blocks' => [
          {
            'source_node_key' => 'note_block:customs_tariff_chapter_note:1.31:72:1:y',
            'source_title' => 'iron plated',
            'source_context' => 'iron plated: Products finished by iron plating.',
            'block_type' => 'definition',
            'term' => 'iron plated',
            'source_type' => 'customs_tariff_chapter_note',
            'source_id' => '72',
            'fragment_node_keys' => [],
          },
        ],
      ),
    )

    plated_contexts = described_class.call(
      query: 'iron plate',
      search_results: [
        search_result_class.new(
          goods_nomenclature_item_id: '7201500000',
          description: 'Iron plate products',
          full_description: nil,
          score: 10,
        ),
      ],
      notes_by_item_id: { '7201500000' => plated_note },
    )

    plated_why = plated_contexts.flat_map { |context| context[:fragments] }.map { |fragment| fragment[:why_relevant] }
    expect(plated_why.join('; ')).not_to include('exact phrase match iron plate')
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

  it 'does not load fragment nodes when metadata has context' do
    queries = sql_queries do
      described_class.call(
        query:,
        search_results:,
        notes_by_item_id: { '9506911000' => note },
      )
    end

    expect(queries.grep(/FROM "tariff_knowledge_nodes"/)).to be_empty
  end

  it 'does not load fragment nodes for block evidence with metadata context and title' do
    block_only_note = create(
      :tariff_knowledge_compressed_note,
      goods_nomenclature_item_id: '7201200000',
      content: 'compressed note block only',
      context_hash: Digest::SHA256.hexdigest('compressed note block only'),
      metadata: Sequel.pg_jsonb_wrap(
        'evidence_blocks' => [
          {
            'source_node_key' => 'note_block:customs_tariff_chapter_note:1.31:72:1:a',
            'source_title' => 'pig Iron',
            'source_context' => 'pig Iron: Iron-carbon alloys not usefully malleable.',
            'block_type' => 'definition',
            'term' => 'pig iron',
            'source_type' => 'customs_tariff_chapter_note',
            'source_id' => '72',
            'fragment_node_keys' => [],
          },
        ],
      ),
    )

    queries = sql_queries do
      described_class.call(
        query: 'pig iron',
        search_results: [
          search_result_class.new(
            goods_nomenclature_item_id: '7201200000',
            description: 'Non-alloy pig iron in pigs, blocks or other primary forms',
            full_description: nil,
            score: 10,
          ),
        ],
        notes_by_item_id: { '7201200000' => block_only_note },
      )
    end

    expect(queries.grep(/FROM "tariff_knowledge_nodes"/)).to be_empty
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

  it 'includes source references for fragment evidence sent to the classifier context' do
    source_note = create_note_with_evidence(
      '9506911000',
      evidence_for(
        'note_fragment:customs_tariff_chapter_note:1.31:95:source',
        'Heading 9506 includes articles and equipment for general physical exercise.',
        'inclusion',
        range_type: 'heading',
        range_code: '9506',
      ),
    )

    contexts = described_class.call(
      query: 'exercise apparatus',
      search_results: [
        search_result_class.new(
          goods_nomenclature_item_id: '9506911000',
          description: 'Articles and equipment for general physical exercise',
          full_description: nil,
          score: 10,
        ),
      ],
      notes_by_item_id: { '9506911000' => source_note },
    )

    expect(contexts.first[:fragments].first[:source_ref]).to eq('chapter 95 note')
  end

  it 'caps total emitted fragments across all selected notes and explains the omissions' do
    selection = described_class.call_with_diagnostics(
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

    expect(selection.contexts.sum { |context| context[:fragments].size }).to eq(described_class::MAX_TOTAL_FRAGMENTS)
    expect(selection.diagnostics[:omitted_evidence]).to include(include(omission_reason: 'total_evidence_limit'))
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

  def evidence_for(key, text, context_type, range_type: nil, range_code: nil, source_type: 'customs_tariff_chapter_note', source_id: '95')
    {
      'source_node_key' => key,
      'source_type' => source_type,
      'source_id' => source_id,
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

  def sql_queries
    queries = []
    logger = Logger.new(StringIO.new)
    logger.formatter = proc do |_severity, _datetime, _progname, message|
      queries << message
      nil
    end

    Sequel::Model.db.loggers << logger
    yield
    queries
  ensure
    Sequel::Model.db.loggers.delete(logger)
  end
end
