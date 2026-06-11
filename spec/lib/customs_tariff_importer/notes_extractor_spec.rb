require 'zip'

RSpec.describe CustomsTariffImporter::NotesExtractor do
  subject(:extractor) { described_class.new('1.30', docx_content) }

  # Builds a minimal .docx (ZIP containing word/document.xml) from a flat list of paragraph strings
  def build_docx(paragraphs)
    ns = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
    para_xml = paragraphs.map { |text|
      escaped = text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
      "<w:p><w:r><w:t>#{escaped}</w:t></w:r></w:p>"
    }.join("\n")

    xml = <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:w="#{ns}">
        <w:body>#{para_xml}</w:body>
      </w:document>
    XML

    buffer = StringIO.new
    buffer.binmode
    Zip::OutputStream.write_buffer(buffer) do |zip|
      zip.put_next_entry('word/document.xml')
      zip.write(xml)
    end
    buffer.string
  end

  # Unit tests for the state machine via parse_notes (private)
  # Paragraphs are passed as plain hashes matching the shape extract_paragraphs returns
  describe 'state machine (unit)' do
    def paragraphs(*texts)
      texts.map { |t| { style: '', text: t } }
    end

    def parse(texts)
      described_class.new('1.30', '').send(:parse_notes, paragraphs(*texts))
    end

    describe 'General Rules of Interpretation' do
      it 'collects rules under their numbers' do
        result = parse([
          'General Interpretive Rules',
          'Rule 1',
          'Goods are to be classified by the heading.',
          'Rule 2',
          'Any reference to an article includes incomplete articles.',
        ])

        expect(result.general_rules['1']).to include('Goods are to be classified')
        expect(result.general_rules['2']).to include('Any reference to an article')
      end

      it 'stops collecting rules at a PART boundary' do
        result = parse([
          'General Interpretive Rules',
          'Rule 1',
          'Rule one content.',
          'PART THREE',
          'Rule 2',
          'Should not be collected.',
        ])

        expect(result.general_rules.keys).to eq(%w[1])
      end

      it 'stops collecting rules when a SECTION header is encountered' do
        result = parse([
          'General Interpretive Rules',
          'Rule 1',
          'Rule content.',
          'SECTION I',
        ])

        expect(result.general_rules['1']).to include('Rule content.')
        expect(result.general_rules.size).to eq(1)
      end
    end

    describe 'section notes' do
      it 'collects notes under the integer section key' do
        result = parse([
          'SECTION I',
          'Section Notes',
          'Live animals shall be classified here.',
          'SECTION II',
          'Section Notes',
          'Vegetable products.',
        ])

        expect(result.sections[1]).to include('Live animals')
        expect(result.sections[2]).to include('Vegetable products')
      end

      it 'converts the section key to an integer' do
        result = parse(['SECTION iv', 'Section Notes', 'Some content.'])
        expect(result.sections.keys).to contain_exactly(4)
      end

      it 'does not save a section with no notes' do
        result = parse(['SECTION I', 'CHAPTER 1'])
        expect(result.sections).to be_empty
      end

      context 'when a chapter header appears before the section notes heading' do
        it 'still captures the section notes' do
          result = parse([
            'SECTION XI',
            'CHAPTER 50',
            'Section notes',
            'This section does not cover bristles.',
            'CHAPTER 51',
          ])
          expect(result.sections[11]).to eq('This section does not cover bristles.')
        end

        it 'stops collecting section notes when a commodity code is encountered' do
          result = parse([
            'SECTION XI',
            'CHAPTER 50',
            'Section notes',
            'Note content.',
            '5001000000',
            'Silkworm cocoons suitable for reeling',
          ])
          expect(result.sections[11]).to eq('Note content.')
        end
      end
    end

    describe 'chapter notes' do
      it 'collects notes under the zero-padded chapter key' do
        result = parse([
          'CHAPTER 1',
          'Chapter Notes',
          'This chapter covers live animals.',
          'CHAPTER 2',
          'Chapter Notes',
          'Meat and edible offal.',
        ])

        expect(result.chapters['01']).to include('live animals')
        expect(result.chapters['02']).to include('Meat')
      end

      it 'zero-pads single-digit chapter numbers' do
        result = parse(['CHAPTER 3', 'Chapter Notes', 'Fish content.'])
        expect(result.chapters.keys).to contain_exactly('03')
      end

      it 'concatenates additional chapter notes into the same chapter' do
        result = parse([
          'CHAPTER 1',
          'Chapter Notes',
          'Primary note.',
          'Additional Chapter Notes',
          'Extra note.',
        ])

        expect(result.chapters['01']).to include('Primary note.')
        expect(result.chapters['01']).to include('Additional Chapter Notes')
        expect(result.chapters['01']).to include('Extra note.')
      end

      it 'stops collecting chapter notes when a 10-digit commodity code is encountered' do
        result = parse([
          'CHAPTER 1',
          'Chapter Notes',
          'First line.',
          '0101010101',
          'Should not appear.',
        ])

        expect(result.chapters['01']).to include('First line.')
        expect(result.chapters['01']).not_to include('Should not appear.')
      end

      it 'does not save a chapter with no notes' do
        result = parse(['CHAPTER 1', 'CHAPTER 2'])
        expect(result.chapters).to be_empty
      end
    end

    describe 'boundary pattern anchoring' do
      it 'does not treat an inline chapter reference within note text as a chapter boundary' do
        result = parse([
          'CHAPTER 72',
          'Chapter Notes',
          '1. Some definition.',
          'Chapter 72 does not include products of heading 7301 or 7302.',
          'More note text.',
          'CHAPTER 73',
          'Chapter Notes',
          'Steel content.',
        ])

        expect(result.chapters['72']).to include('More note text.')
        expect(result.chapters['73']).to include('Steel content.')
      end

      it 'does not treat an inline section reference within note text as a section boundary' do
        result = parse([
          'CHAPTER 5',
          'Chapter Notes',
          '1. Some definition.',
          'Section II also covers related products.',
          'More note text.',
          'CHAPTER 6',
          'Chapter Notes',
          'Next chapter content.',
        ])

        expect(result.chapters['05']).to include('More note text.')
        expect(result.chapters['06']).to include('Next chapter content.')
      end
    end

    describe 'chapter notes without a "Chapter Notes" heading' do
      it 'starts collecting from "Additional chapter notes" when it is the first heading' do
        result = parse([
          'CHAPTER 53',
          'OTHER VEGETABLE TEXTILE FIBRES; PAPER YARN AND WOVEN FABRICS OF PAPER YARN',
          'Additional chapter notes',
          '1. (A) For the purposes of code 5306 10 90, the expression "put up for retail sale" means goods put up:',
          '5306100000',
        ])

        expect(result.chapters['53']).to start_with('Additional chapter notes')
        expect(result.chapters['53']).to include('1. (A) For the purposes of code 5306 10 90')
        expect(result.chapters['53']).not_to include('5306100000')
      end

      it 'starts collecting from "Subheading note" when it is the first heading' do
        result = parse([
          'CHAPTER 52',
          'COTTON',
          'Subheading note',
          "For the purposes of subheadings 5209.42 and 5211.42, the expression 'denim' means fabrics of yarns.",
          '5201000000',
        ])

        expect(result.chapters['52']).to start_with('Subheading note')
        expect(result.chapters['52']).to include("the expression 'denim' means fabrics of yarns.")
        expect(result.chapters['52']).not_to include('5201000000')
      end

      it 'starts collecting from the first numbered note when there is no heading' do
        result = parse([
          'CHAPTER 30',
          'PHARMACEUTICAL PRODUCTS',
          '1. This chapter does not cover:',
          '(a) foods or beverages (such as dietetic, diabetic or fortified foods).',
          '3001000000',
        ])

        expect(result.chapters['30']).to start_with('1. This chapter does not cover:')
        expect(result.chapters['30']).to include('(a) foods or beverages')
        expect(result.chapters['30']).not_to include('3001000000')
      end

      it 'does not mistake a duty-rate percentage for a numbered note' do
        result = parse([
          'CHAPTER 1',
          'LIVE ANIMALS',
          '0.00%',
          'CHAPTER 2',
          'Chapter Notes',
          'Meat content.',
        ])

        expect(result.chapters['01']).to be_nil
        expect(result.chapters['02']).to include('Meat content.')
      end
    end

    describe 'transitions between sections and chapters' do
      it 'moves from collecting a section note to in_chapter when a chapter header appears' do
        result = parse([
          'SECTION I',
          'Section Notes',
          'Live animals shall be classified here.',
          'CHAPTER 1',
          'Chapter Notes',
          'Horses and donkeys.',
        ])

        expect(result.sections[1]).to include('Live animals shall be classified here.')
        expect(result.chapters['01']).to include('Horses and donkeys.')
      end

      it 'finalizes the previous chapter when a new chapter header appears' do
        result = parse([
          'CHAPTER 1',
          'Chapter Notes',
          'Horses and donkeys.',
          'CHAPTER 2',
          'Chapter Notes',
          'Meat and edible offal.',
        ])

        expect(result.chapters.size).to eq(2)
      end

      it 'returns to in_section from collecting_chapter when a section header appears' do
        result = parse([
          'CHAPTER 1',
          'Chapter Notes',
          'Horses and donkeys.',
          'SECTION II',
          'Section Notes',
          'Vegetable products.',
        ])

        expect(result.chapters['01']).to be_present
        expect(result.sections[2]).to include('Vegetable products.')
      end
    end

    describe 'blank paragraph handling' do
      it 'preserves blank paragraphs as blank lines' do
        result = parse([
          'CHAPTER 1',
          'Chapter Notes',
          'Line one.',
          '',
          'Line two.',
        ])

        expect(result.chapters['01']).to include("Line one.\n\nLine two.")
      end
    end
  end

  # Integration tests — full call through read_document_xml → extract_paragraphs → parse_notes
  describe '#call (integration)' do
    before do
      allow(CustomsTariffImporter::Instrumentation).to receive(:parse_started)
      allow(CustomsTariffImporter::Instrumentation).to receive(:document_parsed)
      allow(CustomsTariffImporter::Instrumentation).to receive(:parse_failed)
    end

    context 'with a well-formed .docx' do
      let(:docx_content) do
        build_docx([
          'PART TWO',
          'General Interpretive Rules',
          'Rule 1',
          'Classification shall be determined according to the heading.',
          'PART THREE',
          'SECTION I',
          'Section Notes',
          'This section covers live animals.',
          'CHAPTER 1',
          'Chapter Notes',
          'Live animals of all kinds.',
        ])
      end

      it 'returns a Result with chapters, sections and general_rules' do
        result = extractor.call
        expect(result).to be_a(CustomsTariffImporter::NotesExtractor::Result)
      end

      it 'extracts chapter notes' do
        expect(extractor.call.chapters['01']).to include('Live animals of all kinds.')
      end

      it 'extracts section notes' do
        expect(extractor.call.sections[1]).to include('live animals')
      end

      it 'extracts general rules' do
        expect(extractor.call.general_rules['1']).to include('Classification shall be determined')
      end

      it 'emits parse_started instrumentation' do
        extractor.call
        expect(CustomsTariffImporter::Instrumentation).to have_received(:parse_started).with(version: '1.30')
      end

      it 'emits document_parsed instrumentation with counts' do
        extractor.call
        expect(CustomsTariffImporter::Instrumentation).to have_received(:document_parsed).with(
          version: '1.30',
          chapters: 1,
          sections: 1,
          rules: 1,
          duration_ms: a_kind_of(Float),
        )
      end
    end

    context 'when the .docx has no word/document.xml entry' do
      let(:docx_content) do
        buffer = StringIO.new
        buffer.binmode
        Zip::OutputStream.write_buffer(buffer) do |zip|
          zip.put_next_entry('word/settings.xml')
          zip.write('<settings/>')
        end
        buffer.string
      end

      it 'raises and emits parse_failed instrumentation' do
        expect { extractor.call }.to raise_error(RuntimeError, /word\/document\.xml not found/)
        expect(CustomsTariffImporter::Instrumentation).to have_received(:parse_failed).with(
          version: '1.30',
          error_class: 'RuntimeError',
          error_message: a_string_including('word/document.xml not found'),
        )
      end
    end
  end
end
