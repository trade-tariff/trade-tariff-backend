RSpec.describe TariffKnowledge::RuleExtractor do
  describe '.call' do
    subject(:rules) { described_class.call(source:) }

    let(:source) do
      TariffKnowledge::RuleSource.new(
        key: 'legacy_chapter_note:01',
        source_type: 'ChapterNote',
        source_id: '01',
        source_version: 'legacy',
        title: 'Chapter 01 note',
        content: content,
        scope_type: 'chapter',
        scope_id: '01',
        validity_start_date: Time.zone.today,
        validity_end_date: nil,
      )
    end

    let(:content) do
      <<~TEXT
        1. This chapter covers all live animals except:
        a) fish of heading [0301](/headings/0301); and
        b) cultures of heading [3002](/headings/3002).

        2. In this chapter "purebred breeding animal" means an animal accepted for breeding.

        3. Subject to note 1, goods are to be classified in heading 0101.
      TEXT
    end

    it 'extracts top-level rules' do
      expect(rules.map(&:rule_label)).to eq(%w[1 2 3])
    end

    it 'classifies rule families' do
      expect(rules.map(&:rule_type)).to eq(%w[excludes defines_term classifies_as])
    end

    it 'extracts referenced headings' do
      expect(rules.first.references).to include(
        { type: 'heading', id: '0301', expression: '0301' },
        { type: 'heading', id: '3002', expression: '3002' },
      )
    end

    context 'with customs tariff reference shapes' do
      let(:content) do
        <<~TEXT
          1. Products of headings 04.01 to 04.06 are subject to note 1(A) to Section VI.
          2. Goods of subheading 270111 are classified under heading 2701.
        TEXT
      end

      it 'extracts dotted heading ranges, subheading codes and Roman section references' do
        expect(rules.first.references).to include(
          { type: 'heading_range', from: '0401', to: '0406', expression: '04.01 to 04.06' },
          { type: 'section', id: 6, expression: 'VI' },
        )
        expect(rules.second.references).to include(
          { type: 'goods_nomenclature_code', id: '270111', expression: '270111' },
          { type: 'heading', id: '2701', expression: '2701' },
        )
      end
    end

    context 'with customs tariff boilerplate and compact numbering' do
      let(:content) do
        <<~TEXT
          There are important notes for this part of the tariff: 1.This section does not cover goods of heading 0502.
          2.Goods of subheading 270111 are subject to this note.
        TEXT
      end

      it 'removes the boilerplate and splits compact numbered rules' do
        expect(rules.map(&:rule_label)).to eq(%w[1 2])
        expect(rules.first.content).to start_with('This section does not cover')
      end
    end

    it 'keeps source metadata' do
      expect(rules.first.source).to eq(source)
    end
  end
end
