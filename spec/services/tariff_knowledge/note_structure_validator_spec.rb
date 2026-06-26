RSpec.describe TariffKnowledge::NoteStructureValidator do
  describe '.call' do
    def fragment(sequence, content)
      Data.define(:key, :content).new(
        "note_fragment:customs_tariff_chapter_note:1.31:72:#{sequence}",
        content,
      )
    end

    it 'reports a clean parsed note structure' do
      result = described_class.call(
        source_type: 'customs_tariff_chapter_note',
        source_id: '72',
        source_version: '1.31',
        fragments: [
          fragment('0001', '1. In this chapter the following expressions have meanings:'),
          fragment('0002', 'a. pig Iron'),
          fragment('0003', 'Iron-carbon alloys not usefully malleable.'),
        ],
      )

      aggregate_failures do
        expect(result).to have_attributes(
          source_type: 'customs_tariff_chapter_note',
          source_id: '72',
          source_version: '1.31',
          fragment_count: 3,
          event_count: 3,
          root_node_count: 1,
          total_node_count: 1,
          orphan_event_count: 0,
          orphan_event_keys: [],
          duplicate_block_keys: [],
          uncontained_fragment_keys: [],
          issues: [],
        )
      end
    end

    it 'reports orphan and uncontained fragments without raising' do
      result = described_class.call(
        source_type: 'customs_tariff_chapter_note',
        source_id: '72',
        source_version: '1.31',
        fragments: [
          fragment('0001', '- orphan bullet'),
          fragment('0002', '1. Definitions:'),
          fragment('0003', 'a. steel'),
        ],
      )

      expect(result.orphan_event_keys).to contain_exactly('note_fragment:customs_tariff_chapter_note:1.31:72:0001')
      expect(result.uncontained_fragment_keys).to contain_exactly(
        'note_fragment:customs_tariff_chapter_note:1.31:72:0001',
      )
      expect(result.issues.map(&:code)).to include('orphan_events', 'uncontained_fragments')
    end

    it 'does not report ordinary continuation prose as an uncontained definition fragment' do
      result = described_class.call(
        source_type: 'customs_tariff_chapter_note',
        source_id: '72',
        source_version: '1.31',
        fragments: [
          fragment('0001', '1. General provisions:'),
          fragment('0002', 'This chapter covers goods of iron or steel.'),
        ],
      )

      expect(result.uncontained_fragment_keys).to be_empty
      expect(result.issues.map(&:code)).not_to include('uncontained_fragments')
    end

    it 'reports duplicate block keys from emitted blocks' do
      first_block = TariffKnowledge::NoteBlockParser::Block.new(
        key: 'note_block:customs_tariff_chapter_note:1.31:72:1:a',
        title: 'steel',
        content: 'steel',
        metadata: {},
        fragment_keys: ['note_fragment:customs_tariff_chapter_note:1.31:72:0002'],
      )
      second_block = first_block.with(title: 'steel duplicate')

      result = described_class.call(
        source_type: 'customs_tariff_chapter_note',
        source_id: '72',
        source_version: '1.31',
        fragments: [
          fragment('0001', '1. Definitions:'),
          fragment('0002', 'a. steel'),
        ],
        block_parser: class_double(TariffKnowledge::NoteBlockParser, call: [first_block, second_block]),
      )

      expect(result.duplicate_block_keys).to contain_exactly('note_block:customs_tariff_chapter_note:1.31:72:1:a')
      expect(result.issues.map(&:code)).to include('duplicate_block_keys')
    end

    it 'can split content into source fragments for generic callers' do
      result = described_class.call(
        source_type: 'customs_tariff_chapter_note',
        source_id: '72',
        source_version: '1.31',
        content: "1. Definitions:\n\na. steel\n\nGoods of heading\n8481. C. Further text.",
      )

      expect(result.fragment_count).to eq(4)
      expect(result.source_id).to eq('72')
      expect(result.issues.map(&:code)).not_to include('missing_fragments')
    end
  end
end
