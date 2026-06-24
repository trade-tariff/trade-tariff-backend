RSpec.describe TariffKnowledge::NoteStructureParser do
  describe '.call' do
    def fragment(sequence, content)
      Data.define(:key, :content).new("note_fragment:customs_tariff_chapter_note:1.31:72:#{sequence}", content)
    end

    it 'builds scoped trees for repeated marker paths under headings' do
      tree = described_class.call(
        source_type: 'customs_tariff_chapter_note',
        source_id: '72',
        source_version: '1.31',
        fragments: [
          fragment('0001', '1. In this chapter the following expressions have meanings:'),
          fragment('0002', 'a. pig Iron'),
          fragment('0003', 'Iron-carbon alloys not usefully malleable.'),
          fragment('0004', '- not more than 10 % of chromium'),
          fragment('0072', '### Subheading notes'),
          fragment('0073', '1. In this chapter, the following expressions have meanings:'),
          fragment('0074', 'a. alloy pig iron'),
          fragment('0075', 'Pig iron containing one or more specified elements.'),
        ],
      )

      pig_iron = tree.nodes.find { |node| node.title == 'pig Iron' }
      alloy_pig_iron = tree.nodes.find { |node| node.title == 'alloy pig iron' }

      expect(pig_iron.path).to eq(%w[1 a])
      expect(pig_iron.fragment_keys).to contain_exactly(
        'note_fragment:customs_tariff_chapter_note:1.31:72:0002',
        'note_fragment:customs_tariff_chapter_note:1.31:72:0003',
        'note_fragment:customs_tariff_chapter_note:1.31:72:0004',
      )
      expect(pig_iron.content).to include('Iron-carbon alloys not usefully malleable.')
      expect(pig_iron.content).to include('not more than 10 % of chromium')
      expect(alloy_pig_iron.path).to eq(%w[subheading_notes 1 a])
      expect(alloy_pig_iron.fragment_keys).to contain_exactly(
        'note_fragment:customs_tariff_chapter_note:1.31:72:0074',
        'note_fragment:customs_tariff_chapter_note:1.31:72:0075',
      )
      expect(alloy_pig_iron.content).to include('Pig iron containing one or more specified elements.')
    end

    it 'attaches continuations and bullets to the nearest active structural node' do
      tree = described_class.call(
        source_type: 'customs_tariff_chapter_note',
        source_id: '72',
        source_version: '1.31',
        fragments: [
          fragment('0001', '1. Definitions:'),
          fragment('0002', 'a. steel'),
          fragment('0003', 'Ferrous materials usefully malleable.'),
          fragment('0004', '- with carbon limits'),
          fragment('0005', '- with chromium exceptions'),
        ],
      )

      steel = tree.nodes.find { |node| node.title == 'steel' }
      expect(steel.content).to include('Ferrous materials usefully malleable.')
      expect(steel.content).to include('with carbon limits')
      expect(steel.content).to include('with chromium exceptions')
    end

    it 'nests roman block candidates under active alpha block candidates' do
      tree = described_class.call(
        source_type: 'customs_tariff_chapter_note',
        source_id: '72',
        source_version: '1.31',
        fragments: [
          fragment('0001', '1. Definitions:'),
          fragment('0002', 'a. steel'),
          fragment('0003', '(i) stainless steel'),
          fragment('0004', 'Containing chromium.'),
        ],
      )

      steel = tree.nodes.find { |node| node.title == 'steel' }
      stainless_steel = steel.children.find { |node| node.title == 'stainless steel' }

      expect(tree.nodes.map(&:title)).to include('steel')
      expect(tree.nodes.map(&:title)).not_to include('stainless steel')
      expect(steel.children.map(&:title)).to include('stainless steel')
      expect(stainless_steel.path).to eq(%w[1 a i])
      expect(stainless_steel.content).to include('Containing chromium.')
      expect(stainless_steel.fragment_keys).to contain_exactly(
        'note_fragment:customs_tariff_chapter_note:1.31:72:0003',
        'note_fragment:customs_tariff_chapter_note:1.31:72:0004',
      )
    end

    it 'does not attach sibling continuations to stale nested block candidates' do
      tree = described_class.call(
        source_type: 'customs_tariff_chapter_note',
        source_id: '72',
        source_version: '1.31',
        fragments: [
          fragment('0001', '1. Definitions:'),
          fragment('0002', 'a. steel'),
          fragment('0003', '(i) stainless steel'),
          fragment('0004', 'Containing chromium.'),
          fragment('0005', 'b. iron'),
          fragment('0006', 'Containing carbon.'),
        ],
      )

      steel = tree.nodes.find { |node| node.title == 'steel' }
      iron = tree.nodes.find { |node| node.title == 'iron' }
      stainless_steel = steel.children.find { |node| node.title == 'stainless steel' }

      expect(tree.nodes.map(&:title)).to contain_exactly('steel', 'iron')
      expect(iron.content).to include('Containing carbon.')
      expect(stainless_steel.content).to include('Containing chromium.')
      expect(stainless_steel.content).not_to include('Containing carbon.')
    end

    it 'uses uppercase alpha markers as section scopes for repeated lower alpha lists' do
      tree = described_class.call(
        source_type: 'customs_tariff_chapter_note',
        source_id: '72',
        source_version: '1.31',
        fragments: [
          fragment('0001', '1. Definitions:'),
          fragment('0002', '(A) General rule'),
          fragment('0003', 'a. first condition'),
          fragment('0004', '(B) Exceptions'),
          fragment('0005', 'a. second condition'),
        ],
      )

      general_rule = tree.nodes.find { |node| node.title == 'General rule' }
      exceptions = tree.nodes.find { |node| node.title == 'Exceptions' }
      first_condition = general_rule.children.find { |node| node.title == 'first condition' }
      second_condition = exceptions.children.find { |node| node.title == 'second condition' }

      expect(general_rule).to have_attributes(kind: :alpha_section, path: %w[1 A])
      expect(exceptions).to have_attributes(kind: :alpha_section, path: %w[1 B])
      expect(first_condition.path).to eq(%w[1 A a])
      expect(second_condition.path).to eq(%w[1 B a])
    end

    it 'reports orphan events that cannot attach to a block candidate' do
      tree = described_class.call(
        source_type: 'customs_tariff_chapter_note',
        source_id: '72',
        source_version: '1.31',
        fragments: [
          fragment('0001', '- orphan bullet'),
          fragment('0002', '1. Definitions:'),
          fragment('0003', 'a. steel'),
        ],
      )

      expect(tree.orphans.map { |event| event.fragment.key }).to contain_exactly(
        'note_fragment:customs_tariff_chapter_note:1.31:72:0001',
      )
      expect(tree.nodes.map(&:title)).to include('steel')
    end
  end
end
