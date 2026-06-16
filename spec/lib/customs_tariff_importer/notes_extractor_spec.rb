require 'zip'

RSpec.describe CustomsTariffImporter::NotesExtractor do
  subject(:extractor) { described_class.new('1.30', docx_content) }

  # Builds a minimal .docx (ZIP containing word/document.xml) from a flat list of paragraph strings
  def build_docx(paragraphs)
    para_xml = paragraphs.map { |text|
      escaped = text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
      "<w:p><w:r><w:t>#{escaped}</w:t></w:r></w:p>"
    }.join("\n")

    build_docx_from_body_xml(para_xml)
  end

  def build_docx_from_body_xml(body_xml)
    ns = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
    xml = <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:w="#{ns}">
        <w:body>#{body_xml}</w:body>
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

  def paragraph_xml(text, bold: false)
    escaped = text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    run_properties = bold ? '<w:rPr><w:b/></w:rPr>' : ''

    "<w:p><w:r>#{run_properties}<w:t>#{escaped}</w:t></w:r></w:p>"
  end

  def hyperlink_paragraph_xml(prefix, linked_text, suffix)
    escaped_prefix = prefix.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    escaped_linked_text = linked_text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
    escaped_suffix = suffix.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')

    <<~XML
      <w:p>
        <w:r><w:t>#{escaped_prefix}</w:t></w:r>
        <w:hyperlink w:anchor="target">
          <w:r><w:t>#{escaped_linked_text}</w:t></w:r>
        </w:hyperlink>
        <w:r><w:t>#{escaped_suffix}</w:t></w:r>
      </w:p>
    XML
  end

  def indented_paragraph_xml(text, left:)
    escaped = text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')

    <<~XML
      <w:p>
        <w:pPr><w:ind w:left="#{left}"/></w:pPr>
        <w:r><w:t>#{escaped}</w:t></w:r>
      </w:p>
    XML
  end

  def numbered_paragraph_xml(text, num_id: 1, level: 0)
    escaped = text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')

    <<~XML
      <w:p>
        <w:pPr>
          <w:numPr>
            <w:ilvl w:val="#{level}"/>
            <w:numId w:val="#{num_id}"/>
          </w:numPr>
        </w:pPr>
        <w:r><w:t>#{escaped}</w:t></w:r>
      </w:p>
    XML
  end

  def paragraph_xml_with_paragraph_bold_only(text)
    escaped = text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')

    <<~XML
      <w:p>
        <w:pPr><w:rPr><w:b/></w:rPr></w:pPr>
        <w:r><w:t>#{escaped}</w:t></w:r>
      </w:p>
    XML
  end

  # Unit tests for the state machine via parse_notes (private)
  # Paragraphs are passed as plain hashes matching the shape extract_paragraphs returns
  describe 'state machine (unit)' do
    def paragraphs(*texts)
      texts.map { |t| { style: '', text: t } }
    end

    def paragraph(text, indent: 0, first_line_indent: 0)
      { style: '', text:, indent:, first_line_indent: }
    end

    def parse(texts)
      described_class.new('1.30', '').send(:parse_notes, paragraphs(*texts))
    end

    def parse_paragraphs(paragraphs)
      described_class.new('1.30', '').send(:parse_notes, paragraphs)
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

      it 'normalises compact numbering and indented marker paragraphs' do
        [
          '**There are important section noted for this part of the tariff:**',
          'There are important section noted for this part of the tariff:',
          '**There are important section notes for this part of the tariff**',
        ].each do |preamble|
          result = parse([
            'SECTION XV',
            'Section Notes',
            preamble,
            '1.This section does not cover:',
            '    a. prepared paints;',
            '    b. ferro-cerium;',
            '2.Throughout the nomenclature, the expression means:',
            '    a. articles of heading 7307;',
          ])

          expect(result.sections[15]).not_to include('There are important section')
          expect(result.sections[15]).to include(
            [
              '1. This section does not cover:',
              '',
              '    a. prepared paints;',
              '',
              '    b. ferro-cerium;',
              '',
              '2. Throughout the nomenclature, the expression means:',
              '',
              '    a. articles of heading 7307;',
            ].join("\n"),
          )
        end
      end

      it 'does not save a section with no notes' do
        result = parse(['SECTION I', 'CHAPTER 1'])
        expect(result.sections).to be_empty
      end

      it 'resets indentation for additional section notes' do
        result = parse([
          'SECTION XVI',
          'Section Notes',
          '6. Throughout the nomenclature, the expression electrical and electronic waste means:',
          '(C) This section does not cover municipal waste.',
          'Additional section notes',
          '1. Tools necessary for the assembly or maintenance of machines are to be classified with those machines.',
          '2. General rule of interpretation 2(a) is also applicable to machines imported in split consignments.',
        ])

        expect(result.sections[16]).to include(
          [
            '6. Throughout the nomenclature, the expression electrical and electronic waste means:',
            '',
            '    (C) This section does not cover municipal waste.',
            '',
            '### Additional section notes',
            '',
            '1. Tools necessary for the assembly or maintenance of machines are to be classified with those machines.',
            '',
            '2. General rule of interpretation 2(a) is also applicable to machines imported in split consignments.',
          ].join("\n"),
        )
      end

      it 'does not inherit general rule indentation state' do
        result = parse([
          'General Interpretive Rules',
          'Rule 2',
          '2. A reference to an article includes incomplete articles.',
          'SECTION I',
          'Section Notes',
          '1. Any reference in this section to a particular genus or species includes the young of that genus or species.',
          '2. References to dried products also cover dehydrated, evaporated or freeze-dried products.',
        ])

        expect(result.sections[1]).to eq(
          [
            '1. Any reference in this section to a particular genus or species includes the young of that genus or species.',
            '',
            '2. References to dried products also cover dehydrated, evaporated or freeze-dried products.',
          ].join("\n"),
        )
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

      it 'separates additional chapter note headings from preceding numbered notes' do
        result = parse([
          'CHAPTER 9',
          'Chapter Notes',
          '1. Primary note.',
          '2. Second primary note.',
          'Additional chapter notes',
          '1. Additional note.',
        ])

        expect(result.chapters['09']).to include(
          [
            '2. Second primary note.',
            '',
            '### Additional chapter notes',
            '',
            '1. Additional note.',
          ].join("\n"),
        )
      end

      it 'normalises compact bracketed subnotes and bullet glyphs' do
        result = parse([
          'CHAPTER 20',
          'Chapter Notes',
          'Additional chapter notes',
          '2.(a) The sugar content is multiplied by one of the following factors:',
          '•0.93 in respect of products of codes 2008 20 to 2008 80;',
          '•0.95 in respect of products of the other headings.',
          '(b) The expression Brix value means the direct reading.',
          '3. Products are considered as containing added sugar when:',
          '•pineapples and grapes: 13 %,',
          '•other fruits: 9 %.',
        ])

        expect(result.chapters['20']).to include(
          [
            '2. (a) The sugar content is multiplied by one of the following factors:',
            '',
            '    - 0.93 in respect of products of codes 2008 20 to 2008 80;',
            '',
            '    - 0.95 in respect of products of the other headings.',
            '',
            '    (b) The expression Brix value means the direct reading.',
            '',
            '3. Products are considered as containing added sugar when:',
            '',
            '    - pineapples and grapes: 13 %,',
            '',
            '    - other fruits: 9 %.',
          ].join("\n"),
        )
      end

      it 'ends an alphabetic sublist and keeps following paragraphs under their numbered note' do
        result = parse_paragraphs([
          paragraph('CHAPTER 23'),
          paragraph('Chapter Notes'),
          paragraph('Additional chapter notes'),
          paragraph('2. Code 2306 90 05 includes only residues containing:'),
          paragraph('a. products of an oil content of less than 3 %;', indent: 720),
          paragraph('b. products of an oil content of not less than 3 %;', indent: 720),
          paragraph('For the determination of the starch and protein content, the methods are to be applied.'),
          paragraph('For the determination of the oil and moisture content, the methods are to be applied.'),
          paragraph('Products containing components added after processing are excluded.'),
          paragraph('3. For the purposes of codes 2307 00 11, the following expressions apply:'),
          paragraph('•‘actual alcoholic strength by mass’: the number of kilograms of pure alcohol contained in 100 kg of the product,', indent: 720),
          paragraph('•‘potential alcoholic strength by mass’: the number of kilograms of pure alcohol capable of being produced by total fermentation of the sugars contained in 100 kg of the product,', indent: 720),
          paragraph('•‘total alcoholic strength by mass’: the sum of the actual and potential alcoholic strengths by mass,', indent: 720),
          paragraph('% mas’: the symbol for alcoholic strength by mass.', first_line_indent: 720),
        ])

        expect(result.chapters['23']).to include(
          [
            '2. Code 2306 90 05 includes only residues containing:',
            '',
            '    a. products of an oil content of less than 3 %;',
            '',
            '    b. products of an oil content of not less than 3 %;',
            '',
            '    For the determination of the starch and protein content, the methods are to be applied.',
            '',
            '    For the determination of the oil and moisture content, the methods are to be applied.',
            '',
            '    Products containing components added after processing are excluded.',
            '',
            '3. For the purposes of codes 2307 00 11, the following expressions apply:',
            '',
            '    - ‘actual alcoholic strength by mass’: the number of kilograms of pure alcohol contained in 100 kg of the product,',
            '',
            '    - ‘potential alcoholic strength by mass’: the number of kilograms of pure alcohol capable of being produced by total fermentation of the sugars contained in 100 kg of the product,',
            '',
            '    - ‘total alcoholic strength by mass’: the sum of the actual and potential alcoholic strengths by mass,',
            '',
            '    - % mas’: the symbol for alcoholic strength by mass.',
          ].join("\n"),
        )
      end

      it 'promotes marker paragraphs to markdown lists only when the source has child markers' do
        result = parse_paragraphs([
          paragraph('CHAPTER 30'),
          paragraph('Chapter Notes'),
          paragraph('1. This chapter does not cover:'),
          paragraph('(a) foods or beverages;'),
          paragraph('(b) products containing nicotine.'),
          paragraph('3. For the purposes of headings 3003 and 3004, the following are to be treated:'),
          paragraph('(a) as unmixed products:'),
          paragraph('(1) unmixed products dissolved in water;', first_line_indent: 720),
          paragraph('(2) all goods of Chapter 28 or 29; and', first_line_indent: 720),
          paragraph('(b) as products which have been mixed:'),
          paragraph('(1) colloidal solutions and suspensions;', first_line_indent: 720),
          paragraph('Subheading notes'),
          paragraph('1. For the purposes of subheadings 3002 13 and 3002 14, the following are to be treated:'),
          paragraph('(a) as unmixed products, pure products, whether or not containing impurities;', first_line_indent: 720),
          paragraph('(b) as products which have been mixed:', first_line_indent: 720),
          paragraph('(1) the products mentioned in (a) above dissolved in water or in other solvents;', indent: 1440),
          paragraph('(2) the products mentioned in (a) and (b) (1) above with an added stabiliser;', indent: 1440),
          paragraph('Additional chapter note'),
          paragraph('1. Heading 3004 includes herbal medicinal preparations if they bear the following statements of:'),
          paragraph('(a) the specific diseases, ailments or their symptoms for which the product is to be used;', indent: 720),
          paragraph('(b) the concentration of active substance or substances contained therein;', first_line_indent: 720),
          paragraph('(c) dosage; and', first_line_indent: 720),
          paragraph('(d) mode of application.', first_line_indent: 720),
          paragraph('CHAPTER 39'),
          paragraph('Chapter Notes'),
          paragraph('2. This chapter does not cover:'),
          paragraph('(u) articles of Chapter 90;'),
          paragraph('(v) articles of Chapter 91;'),
          paragraph('(w) articles of Chapter 92;'),
          paragraph('(x) articles of Chapter 94;'),
          paragraph('CHAPTER 40'),
          paragraph('Chapter Notes'),
          paragraph('5. (A) Headings 4001 and 4002 do not apply to rubber compounded with:'),
          paragraph('(1) vulcanising agents;'),
          paragraph('(2) pigments;'),
          paragraph('(B) The presence of the following substances shall not affect classification:'),
          paragraph('(1) emulsifiers or anti-tack agents;'),
          paragraph('(2) small amounts of breakdown products of emulsifiers;'),
          paragraph('CHAPTER 48'),
          paragraph('Chapter Notes'),
          paragraph('5. For the purposes of heading 4802, the following criteria apply:'),
          paragraph('(A). For paper weighing not more than 150 g/m2:'),
          paragraph('a. containing 10 % or more fibres, and', indent: 1440),
          paragraph('1.weighing not more than 80 g/m2; or', indent: 1440, first_line_indent: 720),
          paragraph('2.coloured throughout the mass; or', indent: 1440, first_line_indent: 720),
        ])

        expect(result.chapters['30']).to include(
          [
            '1. This chapter does not cover:',
            '    (a) foods or beverages;',
            '    (b) products containing nicotine.',
          ].join("\n"),
        )
        expect(result.chapters['30']).to include(
          [
            '3. For the purposes of headings 3003 and 3004, the following are to be treated:',
            '    - (a) as unmixed products:',
            '        - (1) unmixed products dissolved in water;',
            '        - (2) all goods of Chapter 28 or 29; and',
            '    - (b) as products which have been mixed:',
            '        - (1) colloidal solutions and suspensions;',
          ].join("\n"),
        )
        expect(result.chapters['30']).to include(
          [
            '### Subheading notes',
            '',
            '1. For the purposes of subheadings 3002 13 and 3002 14, the following are to be treated:',
            '    - (a) as unmixed products, pure products, whether or not containing impurities;',
            '    - (b) as products which have been mixed:',
            '',
            '        - (1) the products mentioned in (a) above dissolved in water or in other solvents;',
            '',
            '        - (2) the products mentioned in (a) and (b) (1) above with an added stabiliser;',
          ].join("\n"),
        )
        expect(result.chapters['30']).to include(
          [
            '### Additional chapter note',
            '',
            '1. Heading 3004 includes herbal medicinal preparations if they bear the following statements of:',
            '',
            '    (a) the specific diseases, ailments or their symptoms for which the product is to be used;',
            '',
            '    (b) the concentration of active substance or substances contained therein;',
            '',
            '    (c) dosage; and',
            '',
            '    (d) mode of application.',
          ].join("\n"),
        )
        expect(result.chapters['39']).to include(
          [
            '2. This chapter does not cover:',
            '    (u) articles of Chapter 90;',
            '    (v) articles of Chapter 91;',
            '    (w) articles of Chapter 92;',
            '    (x) articles of Chapter 94;',
          ].join("\n"),
        )
        expect(result.chapters['40']).to include(
          [
            '5. (A) Headings 4001 and 4002 do not apply to rubber compounded with:',
            '    (1) vulcanising agents;',
            '    (2) pigments;',
            '    (B) The presence of the following substances shall not affect classification:',
            '    (1) emulsifiers or anti-tack agents;',
            '    (2) small amounts of breakdown products of emulsifiers;',
          ].join("\n"),
        )
        expect(result.chapters['48']).to include(
          [
            '5. For the purposes of heading 4802, the following criteria apply:',
            '    (A). For paper weighing not more than 150 g/m2:',
            '',
            '    - a. containing 10 % or more fibres, and',
            '',
            '        1. weighing not more than 80 g/m2; or',
            '',
            '        2. coloured throughout the mass; or',
          ].join("\n"),
        )
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

        expect(result.chapters['53']).to start_with('### Additional chapter notes')
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

        expect(result.chapters['52']).to start_with('### Subheading note')
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

    describe 'recoverable markdown list signal' do
      it 'drops a singleton opening expression-note number and unindents its content' do
        result = parse([
          'CHAPTER 74',
          'Chapter Notes',
          '1. In this chapter, the following expressions have the meanings hereby assigned to them:',
          '',
          'a. Refined copper:',
          '',
          'Metal containing copper.',
          'Subheading note',
          '',
          '1. In this chapter, the following expressions have the meanings hereby assigned to them:',
          '',
          'a. Copper-zinc base alloys (brasses):',
        ])

        expect(result.chapters['74']).to eq(
          [
            'In this chapter, the following expressions have the meanings hereby assigned to them:',
            '',
            'a. Refined copper:',
            '',
            'Metal containing copper.',
            '',
            '### Subheading note',
            '',
            'In this chapter, the following expressions have the meanings hereby assigned to them:',
            '',
            'a. Copper-zinc base alloys (brasses):',
          ].join("\n"),
        )
      end

      it 'keeps an opening expression-note number when the section has later numbered notes' do
        result = parse([
          'CHAPTER 72',
          'Chapter Notes',
          '1. In this chapter, the following expressions have the meanings hereby assigned to them:',
          'a. pig iron',
          'Iron-carbon alloys.',
          '2. Ferrous metals clad with another ferrous metal are to be classified elsewhere.',
        ])

        expect(result.chapters['72']).to include('1. In this chapter')
        expect(result.chapters['72']).to include('2. Ferrous metals clad')
        expect(result.chapters['72']).to include('    a. pig iron')
      end

      it 'keeps numbered-note content indented before rendering' do
        result = parse([
          'CHAPTER 72',
          'Chapter Notes',
          '1. In this chapter, the following expressions have the meanings hereby assigned to them:',
          'a. pig iron',
          'Iron-carbon alloys not usefully malleable, containing one or more of the following:',
          '- not more than 10 % of chromium',
          '- not more than 6 % of manganese',
          'b. spiegeleisen',
          'Additional chapter note',
          '1. For the purposes of code 7201 50 10:',
          '- ferro-alloys contain 4 % or more of iron',
        ])

        expect(result.chapters['72']).to include(
          [
            '1. In this chapter, the following expressions have the meanings hereby assigned to them:',
            '    a. pig iron',
            '    Iron-carbon alloys not usefully malleable, containing one or more of the following:',
            '',
            '    - not more than 10 % of chromium',
            '',
            '    - not more than 6 % of manganese',
            '',
            '    b. spiegeleisen',
            '',
            '### Additional chapter note',
            '',
            '1. For the purposes of code 7201 50 10:',
            '',
            '    - ferro-alloys contain 4 % or more of iron',
          ].join("\n"),
        )
      end

      it 'keeps explicit hyphen bullets nested under their numbered note' do
        result = parse([
          'CHAPTER 72',
          'Chapter Notes',
          '1. In this chapter, the following expressions have the meanings hereby assigned to them:',
          'f. other alloy steel',
          'Steels containing one or more of the following elements:',
          '- 0.3 % or more of aluminium',
          '- 0.0008 % or more of boron',
          'g. remelting scrap ingots of iron or steel',
        ])

        expect(result.chapters['72']).to include(
          [
            '    Steels containing one or more of the following elements:',
            '',
            '    - 0.3 % or more of aluminium',
            '',
            '    - 0.0008 % or more of boron',
            '',
            '    g. remelting scrap ingots of iron or steel',
          ].join("\n"),
        )
      end

      it 'keeps unmarked continuation lines inside the previous bullet item' do
        result = parse([
          'CHAPTER 72',
          'Chapter Notes',
          'Additional chapter note',
          "- 'Tool steel': containing one of the following compositions:",
          '- less than 0.6 % of carbon',
          'and 0.7 % or more of silicon and 0.05 % or more of vanadium',
          'or',
          '4 % or more of tungsten;',
          '- 0.8 % or more of carbon',
        ])

        expect(result.chapters['72']).to include(
          [
            '- less than 0.6 % of carbon',
            '',
            '    and 0.7 % or more of silicon and 0.05 % or more of vanadium',
            '    or',
            '    4 % or more of tungsten;',
            '',
            '- 0.8 % or more of carbon',
          ].join("\n"),
        )
      end

      it 'converts source em dash bullets and keeps following paragraphs outside the bullet' do
        result = parse([
          'CHAPTER 2',
          'Chapter Notes',
          '1. A. The following expressions have the meanings hereby assigned to them:',
          '(c) portions composed of either:',
          '— forequarters comprising all the bones and the scrag;',
          'The forequarters and the hindquarters constituting compensated quarters must be presented together;',
          '(d) unseparated forequarters:',
        ])

        expect(result.chapters['02']).to include(
          [
            '    (c) portions composed of either:',
            '',
            '    - forequarters comprising all the bones and the scrag;',
            '',
            '    The forequarters and the hindquarters constituting compensated quarters must be presented together;',
            '    (d) unseparated forequarters:',
          ].join("\n"),
        )
      end

      it 'splits a lettered item with an inline nested number into a nested numbered list' do
        result = parse([
          'CHAPTER 2',
          'Chapter Notes',
          '1. A. The following expressions have the meanings hereby assigned to them:',
          "(h) 1. 'crop' and 'chuck and blade' cuts, for the purposes of code 0202 30 50: the dorsal part;",
          "2. 'brisket' cut, for the purposes of code 0202 30 50: the lower part.",
          'B. Products covered by additional chapter notes may be presented with or without the vertebral column.',
        ])

        expect(result.chapters['02']).to include(
          [
            '    (h)',
            '',
            "    1. 'crop' and 'chuck and blade' cuts, for the purposes of code 0202 30 50: the dorsal part;",
            '',
            "    2. 'brisket' cut, for the purposes of code 0202 30 50: the lower part.",
            '    B. Products covered by additional chapter notes may be presented with or without the vertebral column.',
          ].join("\n"),
        )
      end

      it 'normalises dotless numbered notes before nested bullets and tables' do
        result = parse([
          'CHAPTER 4',
          'Chapter Notes',
          '3. Previous note.',
          '4 The term “unfit for human consumption” applies when:',
          '• the goods are homogeneously mixed',
          '| Denaturant | Minimum quantity |',
          '| --- | --- |',
          '| Spirit of turpentine | 500 |',
          '5. The duty rate applies.',
        ])

        expect(result.chapters['04']).to include(
          [
            '4. The term “unfit for human consumption” applies when:',
            '',
            '    - the goods are homogeneously mixed',
            '',
            '    | Denaturant | Minimum quantity |',
            '    | --- | --- |',
            '    | Spirit of turpentine | 500 |',
            '',
            '5. The duty rate applies.',
          ].join("\n"),
        )
      end

      it 'restores an omitted first additional chapter note marker when later notes continue the sequence' do
        result = parse([
          'CHAPTER 15',
          'Chapter Notes',
          'Additional chapter notes',
          'For the purposes of subheadings/codes 1507 10 and 1518 00 31:',
          '(a) fixed vegetable oils obtained by pressure are crude if:',
          '— decantation within the normal time limits,',
          '(b) fixed vegetable oils obtained by extraction are crude when indistinguishable;',
          '2.A. Headings 1509 and 1510 cover only oils derived solely from olives.',
          'B. Codes 1509 20 00, 1509 30 00 and 1509 40 00 cover only points 1, 2 and 3 below.',
          '1. For the purposes of code 1509 20 00, extra virgin olive oil means category 1 oil.',
          '2. Code 1509 30 00 covers category 2 oil.',
          '3. Code 1509 40 00 covers category 3 oil.',
          'C. Code 1509 90 00 covers other olive oil.',
          '3. Codes 1522 00 31 and 1522 00 39 do not cover residues.',
        ])

        expect(result.chapters['15']).to include(
          [
            '### Additional chapter notes',
            '',
            '1. For the purposes of subheadings/codes 1507 10 and 1518 00 31:',
            '',
            '    (a) fixed vegetable oils obtained by pressure are crude if:',
            '',
            '    - decantation within the normal time limits,',
            '',
            '    (b) fixed vegetable oils obtained by extraction are crude when indistinguishable;',
            '',
            '2. A. Headings 1509 and 1510 cover only oils derived solely from olives.',
            '    B. Codes 1509 20 00, 1509 30 00 and 1509 40 00 cover only points 1, 2 and 3 below.',
            '',
            '    1. For the purposes of code 1509 20 00, extra virgin olive oil means category 1 oil.',
            '',
            '    2. Code 1509 30 00 covers category 2 oil.',
            '',
            '    3. Code 1509 40 00 covers category 3 oil.',
            '    C. Code 1509 90 00 covers other olive oil.',
            '',
            '3. Codes 1522 00 31 and 1522 00 39 do not cover residues.',
          ].join("\n"),
        )
      end

      it 'joins same-note paragraph continuations split mid-phrase by the source document' do
        result = parse([
          'CHAPTER 15',
          'Chapter Notes',
          '5. Food preparations are excluded by their specific form of',
          'presentation revealing their function.',
        ])

        expect(result.chapters['15']).to eq(
          '5. Food preparations are excluded by their specific form of presentation revealing their function.',
        )
      end

      it 'keeps consecutive indented source paragraphs separate under a numbered note' do
        result = parse([
          'CHAPTER 17',
          'Chapter Notes',
          '3. For products of codes 1702 2010, the sugar content is determined using the following formula:',
          'S + 0,95 x (F + G) + M',
          'where:',
          '“S” is the sucrose content determined by the HPLC method;',
          '“F” is the fructose content determined by the HPLC method;',
          '“G” is the glucose content determined by the HPLC method;',
          '“M” is the maltose content determined by the HPLC method.',
        ])

        expect(result.chapters['17']).to include(
          [
            '    “S” is the sucrose content determined by the HPLC method;',
            '',
            '    “F” is the fructose content determined by the HPLC method;',
            '',
            '    “G” is the glucose content determined by the HPLC method;',
            '',
            '    “M” is the maltose content determined by the HPLC method.',
          ].join("\n"),
        )
      end

      it 'normalises compact note markers and lettered paragraph lists after colon lead-ins' do
        result = parse([
          'CHAPTER 34',
          'Chapter Notes',
          '5.In heading 3404, artificial waxes and prepared waxes applies only to:',
          'a. chemically produced organic products of a waxy character;',
          'b. products obtained by mixing different waxes;',
          'c. products of a waxy character with a basis of one or more waxes.',
          'The heading does not apply to:',
          '(a) products of heading 1516;',
          '(b) unmixed animal waxes;',
          '(c) mineral waxes; or',
          '(d) waxes mixed with a liquid medium.',
        ])

        expect(result.chapters['34']).to include(
          [
            '5. In heading 3404, artificial waxes and prepared waxes applies only to:',
            '',
            '    - a. chemically produced organic products of a waxy character;',
            '',
            '    - b. products obtained by mixing different waxes;',
            '',
            '    - c. products of a waxy character with a basis of one or more waxes.',
            '',
            '    The heading does not apply to:',
            '',
            '    - (a) products of heading 1516;',
            '',
            '    - (b) unmixed animal waxes;',
            '',
            '    - (c) mineral waxes; or',
            '',
            '    - (d) waxes mixed with a liquid medium.',
          ].join("\n"),
        )
      end

      it 'does not normalise a dotless number unless it continues the top-level note sequence' do
        result = parse([
          'CHAPTER 4',
          'Chapter Notes',
          '1. Previous note.',
          '4 The goods are put up in containers.',
        ])

        expect(result.chapters['04']).to include(
          [
            '1. Previous note.',
            '    4 The goods are put up in containers.',
          ].join("\n"),
        )
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

    context 'with source formatting in the .docx' do
      it 'converts Word tables to markdown before storing chapter notes' do
        table_xml = <<~XML
          <w:tbl>
            <w:tr>
              <w:tc>
                <w:tcPr><w:gridSpan w:val="2"/></w:tcPr>
                <w:p><w:r><w:t>Element</w:t></w:r></w:p>
              </w:tc>
              <w:tc><w:p><w:r><w:t>Limiting content % by weight</w:t></w:r></w:p></w:tc>
            </w:tr>
            <w:tr>
              <w:tc><w:p><w:r><w:t>Ag</w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t>Silver | gold \\ alloy</w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t>0,25</w:t></w:r></w:p></w:tc>
            </w:tr>
            <w:tr>
              <w:tc><w:p><w:r><w:t>Other elements are, for example, Al, Be, Co, Fe, Mn, Ni, Si.</w:t></w:r></w:p></w:tc>
              <w:tc><w:p/></w:tc>
              <w:tc><w:p><w:r><w:t>0.3</w:t></w:r></w:p></w:tc>
            </w:tr>
          </w:tbl>
        XML

        docx_content = build_docx_from_body_xml([
          paragraph_xml('CHAPTER 74', bold: true),
          paragraph_xml('Chapter Notes', bold: true),
          paragraph_xml('1. In this chapter, the following expressions have the meanings hereby assigned to them:'),
          paragraph_xml('Other elements', bold: true),
          table_xml,
          paragraph_xml('b. Copper alloys:'),
        ].join("\n"))

        result = described_class.new('1.30', docx_content).call

        expect(result.chapters['74']).to include(<<~MARKDOWN.strip)
          **Other elements**

          | Element | Limiting content % by weight |
          | --- | --- |
          | Ag Silver \\| gold \\\\ alloy | 0,25 |
          | Other elements are, for example, Al, Be, Co, Fe, Mn, Ni, Si. | 0.3 |
        MARKDOWN
        expect(result.chapters['74']).not_to include("Ag\n    Silver\n    0,25")
      end

      it 'preserves table columns from spanned multi-row headers' do
        table_xml = <<~XML
          <w:tbl>
            <w:tr>
              <w:tc><w:p><w:r><w:t>Cereal</w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t>Starch content</w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t>Ash content</w:t></w:r></w:p></w:tc>
              <w:tc>
                <w:tcPr><w:gridSpan w:val="2"/></w:tcPr>
                <w:p><w:r><w:t>Rate of passage through a sieve with an aperture of</w:t></w:r></w:p>
              </w:tc>
            </w:tr>
            <w:tr>
              <w:tc><w:p><w:r><w:t> </w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t> </w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t> </w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t>315 micrometres (microns)</w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t>500 micrometres (microns)</w:t></w:r></w:p></w:tc>
            </w:tr>
            <w:tr>
              <w:tc><w:p><w:r><w:t>(1)</w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t>(2)</w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t>(3)</w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t>(4)</w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t>(5)</w:t></w:r></w:p></w:tc>
            </w:tr>
            <w:tr>
              <w:tc><w:p><w:r><w:t>Maize (corn) and grain sorghum</w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t>45 %</w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t>2 %</w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t>—</w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t>90 %</w:t></w:r></w:p></w:tc>
            </w:tr>
          </w:tbl>
        XML

        docx_content = build_docx_from_body_xml([
          paragraph_xml('CHAPTER 11', bold: true),
          paragraph_xml('Chapter Notes', bold: true),
          paragraph_xml('2. Products are classified according to the table:'),
          table_xml,
        ].join("\n"))

        result = described_class.new('1.30', docx_content).call

        expect(result.chapters['11']).to include(
          [
            '    | Cereal | Starch content | Ash content | Rate of passage through a sieve with an aperture of 315 micrometres (microns) | Rate of passage through a sieve with an aperture of 500 micrometres (microns) |',
            '    | --- | --- | --- | --- | --- |',
            '    | (1) | (2) | (3) | (4) | (5) |',
            '    | Maize (corn) and grain sorghum | 45 % | 2 % | — | 90 % |',
          ].join("\n"),
        )
      end

      it 'preserves grouped table columns when a top header spans several subcolumns' do
        table_xml = <<~XML
          <w:tbl>
            <w:tr>
              <w:tc>
                <w:tcPr><w:gridSpan w:val="3"/></w:tcPr>
                <w:p><w:r><w:t>Denaturant</w:t></w:r></w:p>
              </w:tc>
              <w:tc><w:p><w:r><w:t>Minimum quantity to be used (in g) per 100 kg of denatured product</w:t></w:r></w:p></w:tc>
            </w:tr>
            <w:tr>
              <w:tc>
                <w:tcPr><w:gridSpan w:val="3"/></w:tcPr>
                <w:p><w:r><w:t>(1)</w:t></w:r></w:p>
              </w:tc>
              <w:tc><w:p><w:r><w:t>(2)</w:t></w:r></w:p></w:tc>
            </w:tr>
            <w:tr>
              <w:tc><w:p><w:r><w:t>Chemical name or description</w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t>Common name</w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t>Colour index</w:t></w:r></w:p></w:tc>
              <w:tc><w:p/></w:tc>
            </w:tr>
            <w:tr>
              <w:tc><w:p><w:r><w:t>Sodium salt of 4-sulphobenzeneazo-resorcinol</w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t>Chrysoine S</w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t>14270</w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t>6</w:t></w:r></w:p></w:tc>
            </w:tr>
          </w:tbl>
        XML

        docx_content = build_docx_from_body_xml([
          paragraph_xml('CHAPTER 25', bold: true),
          paragraph_xml('Chapter Notes', bold: true),
          paragraph_xml('2. The term denatured applies when:'),
          table_xml,
        ].join("\n"))

        result = described_class.new('1.30', docx_content).call

        expect(result.chapters['25']).to include(
          [
            '    | Denaturant |  |  | Minimum quantity to be used (in g) per 100 kg of denatured product |',
            '    | --- | --- | --- | --- |',
            '    | (1) |  |  | (2) |',
            '    | Chemical name or description | Common name | Colour index |  |',
            '    | Sodium salt of 4-sulphobenzeneazo-resorcinol | Chrysoine S | 14270 | 6 |',
          ].join("\n"),
        )
      end

      it 'uses source indentation to recover nested marker lists' do
        docx_content = build_docx_from_body_xml([
          paragraph_xml('CHAPTER 84', bold: true),
          paragraph_xml('Chapter Notes', bold: true),
          numbered_paragraph_xml('This chapter does not cover:', num_id: 23),
          indented_paragraph_xml('a. millstones, grindstones or other articles of Chapter 68;', left: 720),
          indented_paragraph_xml('b. machinery or appliances of ceramic material;', left: 720),
          numbered_paragraph_xml('Subject to the operation of note 3 to Section XVI, a machine is to be classified under the former group.', num_id: 23),
          indented_paragraph_xml('(A) Heading 8419 does not, however, cover:', left: 1080),
          indented_paragraph_xml('i. germination plant, incubators or brooders (heading 8436);', left: 1800),
          indented_paragraph_xml('ii. grain dampening machines (heading 8437);', left: 1800),
          indented_paragraph_xml('(B) Heading 8422 does not cover:', left: 1080),
          indented_paragraph_xml('i. sewing machines for closing bags or similar containers (heading 8452); or', left: 1800),
          indented_paragraph_xml('ii. office machinery of heading 8472.', left: 1800),
          numbered_paragraph_xml('Heading 8457 applies only to machine tools for working metal either:', num_id: 23),
          indented_paragraph_xml('a. by automatic tool change from a magazine;', left: 1800),
          indented_paragraph_xml('b. by the automatic use of different unit heads;', left: 1800),
          numbered_paragraph_xml('For the purposes of heading 8471, automatic data-processing machines means machines, capable of', num_id: 23),
          indented_paragraph_xml('(1) storing the processing program;', left: 1800),
          indented_paragraph_xml('(2) being freely programmed;', left: 1080),
        ].join("\n"))

        result = described_class.new('1.30', docx_content).call

        expect(result.chapters['84']).to include(
          [
            '1. This chapter does not cover:',
            '',
            '    a. millstones, grindstones or other articles of Chapter 68;',
            '',
            '    b. machinery or appliances of ceramic material;',
            '',
            '2. Subject to the operation of note 3 to Section XVI, a machine is to be classified under the former group.',
            '',
            '    - (A) Heading 8419 does not, however, cover:',
            '',
            '        - i. germination plant, incubators or brooders (heading 8436);',
            '',
            '        - ii. grain dampening machines (heading 8437);',
            '',
            '    - (B) Heading 8422 does not cover:',
            '',
            '        - i. sewing machines for closing bags or similar containers (heading 8452); or',
            '',
            '        - ii. office machinery of heading 8472.',
            '',
            '3. Heading 8457 applies only to machine tools for working metal either:',
            '',
            '    a. by automatic tool change from a magazine;',
            '',
            '    b. by the automatic use of different unit heads;',
            '',
            '4. For the purposes of heading 8471, automatic data-processing machines means machines, capable of',
            '',
            '    (1) storing the processing program;',
            '',
            '    (2) being freely programmed;',
          ].join("\n"),
        )
      end

      it 'keeps source-indented definition paragraphs and roman bracket conditions out of code blocks' do
        docx_content = build_docx_from_body_xml([
          paragraph_xml('CHAPTER 75', bold: true),
          paragraph_xml('Subheading notes', bold: true),
          numbered_paragraph_xml('In this chapter, the following expressions have the meanings hereby assigned to them:', num_id: 24),
          indented_paragraph_xml('a. nickel, not alloyed:', left: 720),
          indented_paragraph_xml('Metal containing by weight at least 99 % of nickel plus cobalt, provided that:', left: 720),
          indented_paragraph_xml('(i) the cobalt content by weight does not exceed 1.5 %, and', left: 1800),
          indented_paragraph_xml('(ii) the content by weight of any other element does not exceed the limit specified in the following table:', left: 1800),
        ].join("\n"))

        result = described_class.new('1.30', docx_content).call

        expect(result.chapters['75']).to include(
          [
            '### Subheading notes',
            '',
            '1. In this chapter, the following expressions have the meanings hereby assigned to them:',
            '',
            '    a. nickel, not alloyed:',
            '',
            '    Metal containing by weight at least 99 % of nickel plus cobalt, provided that:',
            '',
            '    (i) the cobalt content by weight does not exceed 1.5 %, and',
            '',
            '    (ii) the content by weight of any other element does not exceed the limit specified in the following table:',
          ].join("\n"),
        )
      end

      it 'preserves source bold without inventing bold for plain paragraphs' do
        docx_content = build_docx_from_body_xml([
          paragraph_xml('CHAPTER 74', bold: true),
          paragraph_xml('Chapter Notes', bold: true),
          paragraph_xml('1. In this chapter, the following expressions have the meanings hereby assigned to them:'),
          paragraph_xml('a. Refined copper:'),
          paragraph_xml('Actually bold source text', bold: true),
        ].join("\n"))

        result = described_class.new('1.30', docx_content).call

        expect(result.chapters['74']).to include("a. Refined copper:\n\n**Actually bold source text**")
        expect(result.chapters['74']).not_to include('**a. Refined copper:**')
      end

      it 'keeps numbered note markers outside source paragraph bold markdown' do
        docx_content = build_docx_from_body_xml([
          paragraph_xml('CHAPTER 7', bold: true),
          paragraph_xml('Chapter Notes', bold: true),
          paragraph_xml('5. Heading 0711 applies to preserved vegetables.', bold: true),
        ].join("\n"))

        result = described_class.new('1.30', docx_content).call

        expect(result.chapters['07']).to eq('5. **Heading 0711 applies to preserved vegetables.**')
      end

      it 'does not treat paragraph property bold as visible text bold' do
        docx_content = build_docx_from_body_xml([
          paragraph_xml('CHAPTER 7', bold: true),
          paragraph_xml('Chapter Notes', bold: true),
          paragraph_xml_with_paragraph_bold_only('5. Heading 0711 applies to preserved vegetables.'),
        ].join("\n"))

        result = described_class.new('1.30', docx_content).call

        expect(result.chapters['07']).to eq('5. Heading 0711 applies to preserved vegetables.')
      end

      it 'preserves visible text inside hyperlink-wrapped runs' do
        docx_content = build_docx_from_body_xml([
          paragraph_xml('CHAPTER 20', bold: true),
          paragraph_xml('Chapter Notes', bold: true),
          hyperlink_paragraph_xml('1. Products of heading ', '2009', ' are covered by this chapter.'),
        ].join("\n"))

        result = described_class.new('1.30', docx_content).call

        expect(result.chapters['20']).to eq('1. Products of heading 2009 are covered by this chapter.')
      end

      it 'resets visual numbering counters between chapter notes sharing a Word numId' do
        docx_content = build_docx_from_body_xml([
          paragraph_xml('CHAPTER 84', bold: true),
          paragraph_xml('Chapter Notes', bold: true),
          numbered_paragraph_xml('This chapter does not cover:', num_id: 23),
          paragraph_xml('CHAPTER 85', bold: true),
          paragraph_xml('Chapter Notes', bold: true),
          numbered_paragraph_xml('This chapter does not cover:', num_id: 23),
        ].join("\n"))

        result = described_class.new('1.30', docx_content).call

        expect(result.chapters['84']).to eq('1. This chapter does not cover:')
        expect(result.chapters['85']).to eq('1. This chapter does not cover:')
      end

      it 'uses commodity tables as note boundaries instead of note markdown' do
        commodity_table_xml = <<~XML
          <w:tbl>
            <w:tr>
              <w:tc><w:p><w:r><w:t>7401000000</w:t></w:r></w:p></w:tc>
              <w:tc><w:p><w:r><w:t>Copper mattes</w:t></w:r></w:p></w:tc>
            </w:tr>
          </w:tbl>
        XML

        docx_content = build_docx_from_body_xml([
          paragraph_xml('CHAPTER 74'),
          paragraph_xml('Chapter Notes'),
          paragraph_xml('1. Note content.'),
          commodity_table_xml,
          paragraph_xml('This commodity description should not be captured.'),
        ].join("\n"))

        result = described_class.new('1.30', docx_content).call

        expect(result.chapters['74']).to eq('1. Note content.')
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
