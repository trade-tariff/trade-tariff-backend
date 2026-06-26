RSpec.describe TariffKnowledge::NoteBlockParser do
  describe '.call' do
    it 'groups a definition label with its definition body and child composition bullets' do
      fragments = [
        build_fragment('0001', '1. In this chapter the following expressions have the meanings hereby assigned to them:'),
        build_fragment('0002', 'a. pig Iron'),
        build_fragment('0003', 'Iron-carbon alloys not usefully malleable, containing more than 2 % by weight of carbon and which may contain by weight one or more other elements within the following limits:'),
        build_fragment('0004', '- not more than 10 % of chromium'),
        build_fragment('0005', '- not more than 6 % of manganese'),
        build_fragment('0006', '- not more than 3 % of phosphorus'),
        build_fragment('0007', '- not more than 8 % of silicon'),
        build_fragment('0008', '- a total of not more than 10 % of other elements.'),
        build_fragment('0009', 'b. spiegeleisen'),
        build_fragment('0010', 'Iron-carbon alloys containing by weight more than 6 % but not more than 30 % of manganese and otherwise conforming to the specification at (a) above.'),
      ]

      blocks = described_class.call(
        source_type: 'customs_tariff_chapter_note',
        source_id: '72',
        source_version: '1.31',
        fragments:,
      )

      pig_iron = blocks.find { |block| block.metadata['term'] == 'pig iron' }
      expect(pig_iron).to have_attributes(
        key: 'note_block:customs_tariff_chapter_note:1.31:72:1:a',
        title: 'pig Iron',
        content: a_string_including('Iron-carbon alloys not usefully malleable'),
      )
      expect(pig_iron.content).to include('not more than 10 % of chromium')
      expect(pig_iron.content).to include('not more than 6 % of manganese')
      expect(pig_iron.fragment_keys).to eq(
        %w[
          note_fragment:customs_tariff_chapter_note:1.31:72:0002
          note_fragment:customs_tariff_chapter_note:1.31:72:0003
          note_fragment:customs_tariff_chapter_note:1.31:72:0004
          note_fragment:customs_tariff_chapter_note:1.31:72:0005
          note_fragment:customs_tariff_chapter_note:1.31:72:0006
          note_fragment:customs_tariff_chapter_note:1.31:72:0007
          note_fragment:customs_tariff_chapter_note:1.31:72:0008
        ],
      )

      spiegeleisen = blocks.find { |block| block.metadata['term'] == 'spiegeleisen' }
      expect(spiegeleisen.content).to include('more than 6 % but not more than 30 % of manganese')
      expect(spiegeleisen.fragment_keys).to eq(
        %w[
          note_fragment:customs_tariff_chapter_note:1.31:72:0009
          note_fragment:customs_tariff_chapter_note:1.31:72:0010
        ],
      )
    end

    it 'scopes repeated marker paths under markdown headings' do
      fragments = [
        build_fragment('0001', '1. In this chapter and, in the case of notes (d), (e) and (f) throughout the nomenclature, the following expressions have the meanings hereby assigned to them:'),
        build_fragment('0002', 'a. pig Iron'),
        build_fragment('0003', 'Iron-carbon alloys not usefully malleable, containing more than 2 % by weight of carbon.'),
        build_fragment('0072', '### Subheading notes'),
        build_fragment('0073', '1. In this chapter, the following expressions have the meanings hereby assigned to them:'),
        build_fragment('0074', 'a. alloy pig iron'),
        build_fragment('0075', 'Pig iron containing, by weight, one or more of the following elements in the specified proportions:'),
      ]

      blocks = described_class.call(
        source_type: 'customs_tariff_chapter_note',
        source_id: '72',
        source_version: '1.31',
        fragments:,
      )

      pig_iron = blocks.find { |block| block.metadata['term'] == 'pig iron' }
      alloy_pig_iron = blocks.find { |block| block.metadata['term'] == 'alloy pig iron' }

      aggregate_failures do
        expect(pig_iron).to have_attributes(
          key: 'note_block:customs_tariff_chapter_note:1.31:72:1:a',
          content: a_string_including('Iron-carbon alloys not usefully malleable'),
        )
        expect(alloy_pig_iron).to have_attributes(
          key: 'note_block:customs_tariff_chapter_note:1.31:72:subheading_notes:1:a',
          content: a_string_including('Pig iron containing'),
        )
        expect(pig_iron.key).not_to eq(alloy_pig_iron.key)
        expect(pig_iron.metadata['path']).to eq(%w[1 a])
        expect(alloy_pig_iron.metadata['path']).to eq(%w[subheading_notes 1 a])
      end
    end

    it 'emits nested roman block candidates with distinct scoped keys and paths' do
      fragments = [
        build_fragment('0001', '1. In this chapter the following expressions have the meanings hereby assigned to them:'),
        build_fragment('0002', 'a. stainless steel'),
        build_fragment('0003', 'Alloy steels containing chromium.'),
        build_fragment('0004', '(i) cold-rolled stainless steel'),
        build_fragment('0005', 'Flat-rolled products further worked than hot-rolled.'),
      ]

      blocks = described_class.call(
        source_type: 'customs_tariff_chapter_note',
        source_id: '72',
        source_version: '1.31',
        fragments:,
      )

      stainless_steel = blocks.find { |block| block.metadata['term'] == 'stainless steel' }
      cold_rolled = blocks.find { |block| block.metadata['term'] == 'cold-rolled stainless steel' }

      aggregate_failures do
        expect(stainless_steel).to have_attributes(
          key: 'note_block:customs_tariff_chapter_note:1.31:72:1:a',
          content: a_string_including('Alloy steels containing chromium.'),
        )
        expect(stainless_steel.content).to include('cold-rolled stainless steel')
        expect(stainless_steel.content).to include('Flat-rolled products further worked than hot-rolled.')
        expect(stainless_steel.fragment_keys).to eq(
          %w[
            note_fragment:customs_tariff_chapter_note:1.31:72:0002
            note_fragment:customs_tariff_chapter_note:1.31:72:0003
            note_fragment:customs_tariff_chapter_note:1.31:72:0004
            note_fragment:customs_tariff_chapter_note:1.31:72:0005
          ],
        )
        expect(cold_rolled).to have_attributes(
          key: 'note_block:customs_tariff_chapter_note:1.31:72:1:a:i',
          content: a_string_including('Flat-rolled products further worked than hot-rolled.'),
        )
        expect(stainless_steel.metadata['path']).to eq(%w[1 a])
        expect(cold_rolled.metadata['path']).to eq(%w[1 a i])
        expect(cold_rolled.metadata['marker_kind']).to eq('roman')
        expect(stainless_steel.key).not_to eq(cold_rolled.key)
      end
    end

    it 'does not emit standalone marker lists outside numeric note paths as definition blocks' do
      fragments = [
        build_fragment('0001', '(a) goods wholly obtained in a country'),
        build_fragment('0002', 'including mineral products extracted there.'),
      ]

      blocks = described_class.call(
        source_type: 'customs_tariff_chapter_note',
        source_id: '72',
        source_version: '1.31',
        fragments:,
      )

      expect(blocks).to be_empty
    end

    it 'scopes repeated lower alpha blocks below uppercase section markers without emitting the section markers' do
      fragments = [
        build_fragment('0001', '1. Definitions:'),
        build_fragment('0002', '(A) General rule'),
        build_fragment('0003', 'a. first condition'),
        build_fragment('0004', '(B) Exceptions'),
        build_fragment('0005', 'a. second condition'),
      ]

      blocks = described_class.call(
        source_type: 'customs_tariff_chapter_note',
        source_id: '72',
        source_version: '1.31',
        fragments:,
      )

      expect(blocks.map(&:key)).to contain_exactly(
        'note_block:customs_tariff_chapter_note:1.31:72:1:A:a',
        'note_block:customs_tariff_chapter_note:1.31:72:1:B:a',
      )
      expect(blocks.map { |block| block.metadata['term'] }).to contain_exactly('first condition', 'second condition')
    end

    it 'adds a repeat scope when the same marker path is reused without an explicit section marker' do
      fragments = [
        build_fragment('0001', '5. The expression applies only to:'),
        build_fragment('0002', 'a. included product'),
        build_fragment('0003', 'b. included mixture'),
        build_fragment('0004', 'The heading does not apply to:'),
        build_fragment('0005', '(a) excluded product'),
        build_fragment('0006', '(b) excluded mixture'),
      ]

      blocks = described_class.call(
        source_type: 'customs_tariff_chapter_note',
        source_id: '34',
        source_version: '1.31',
        fragments:,
      )

      expect(blocks.map(&:key)).to contain_exactly(
        'note_block:customs_tariff_chapter_note:1.31:34:5:a',
        'note_block:customs_tariff_chapter_note:1.31:34:5:b',
        'note_block:customs_tariff_chapter_note:1.31:34:5:repeat_2:a',
        'note_block:customs_tariff_chapter_note:1.31:34:5:repeat_2:b',
      )
    end

    def build_fragment(sequence, content)
      Data.define(:key, :content).new(
        "note_fragment:customs_tariff_chapter_note:1.31:72:#{sequence}",
        content,
      )
    end
  end
end
