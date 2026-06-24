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

    def build_fragment(sequence, content)
      Data.define(:key, :content).new(
        "note_fragment:customs_tariff_chapter_note:1.31:72:#{sequence}",
        content,
      )
    end
  end
end
