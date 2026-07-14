require 'rails_helper'

RSpec.describe XiCnImporter::NotesExtractor do
  def extract(html)
    described_class.new('32025R1926', html).call
  end

  let(:gri_only_html) do
    <<~HTML
      <?xml version="1.0" encoding="UTF-8"?>
      <html xmlns="http://www.w3.org/1999/xhtml"><body>
      <p class="oj-ti-grseq-1">PART ONE</p>
      <p class="oj-ti-grseq-1"><span class="oj-italic">SECTION I</span></p>
      <p class="oj-ti-grseq-1"><span class="oj-bold">A. General rules</span></p>
      <table><tbody>
        <tr>
          <td><p class="oj-normal">1.</p></td>
          <td><p class="oj-normal">Classification shall be determined according to the terms of the headings.</p></td>
        </tr>
        <tr>
          <td><p class="oj-normal">2.</p></td>
          <td><p class="oj-normal">Any reference in a heading to an article shall be taken to include a reference to that article.</p></td>
        </tr>
      </tbody></table>
      </body></html>
    HTML
  end

  let(:full_fixture_html) do
    <<~HTML
      <?xml version="1.0" encoding="UTF-8"?>
      <html xmlns="http://www.w3.org/1999/xhtml"><body>
      <p class="oj-ti-grseq-1">PART ONE</p>
      <table><tbody>
        <tr><td><p class="oj-normal">1.</p></td><td><p class="oj-normal">GRI rule one.</p></td></tr>
      </tbody></table>
      <p class="oj-ti-grseq-1"><span class="oj-bold">SCHEDULE OF CUSTOMS DUTIES</span></p>
      <p class="oj-ti-grseq-1"><span class="oj-italic">SECTION I</span></p>
      <p class="oj-ti-annotation"><span class="oj-bold">Notes</span></p>
      <table><tbody>
        <tr>
          <td><p class="normal">1.</p></td>
          <td><p class="normal">This section does not cover goods of Chapter 1.</p></td>
        </tr>
        <tr>
          <td><p class="normal">2.</p></td>
          <td>
            <p class="normal">In this section the following expressions apply:</p>
            <table><tbody>
              <tr><td><p class="oj-normal">(a)</p></td><td><p class="oj-normal">First sub-item text.</p></td></tr>
              <tr><td><p class="oj-normal">(b)</p></td><td><p class="oj-normal">Second sub-item text.</p></td></tr>
            </tbody></table>
          </td>
        </tr>
      </tbody></table>
      <p class="oj-ti-grseq-1"><span class="oj-italic">CHAPTER 1</span></p>
      <p class="oj-ti-annotation"><span class="oj-bold">Note</span></p>
      <table><tbody>
        <tr><td><p class="normal">1.</p></td><td><p class="normal">This chapter covers all live animals.</p></td></tr>
      </tbody></table>
      <p class="oj-ti-annotation">Additional notes</p>
      <table><tbody>
        <tr><td><p class="normal">1.</p></td><td><p class="normal">For the purposes of subheading 0101 21 the following applies.</p></td></tr>
      </tbody></table>
      <table class="oj-table"><tbody>
        <tr><td>0101000000</td><td>Live horses</td></tr>
      </tbody></table>
      </body></html>
    HTML
  end

  describe 'footnote anchor stripping' do
    it 'strips EU OJ footnote back-reference links (href="#ntr...") from cell text' do
      # Actual EU OJ XHTML structure: the footnote number sits inside an <a href="#ntr...">
      # with an oj-note-tag <span>. The surrounding ( and ) are also inside the <a>.
      html = <<~HTML
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <p class="oj-ti-grseq-1">PART ONE</p>
        <p class="oj-ti-grseq-1"><span class="oj-bold">SCHEDULE OF CUSTOMS DUTIES</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">SECTION I</span></p>
        <p class="oj-ti-annotation"><span class="oj-bold">Notes</span></p>
        <table><tbody>
          <tr>
            <td><p class="normal">1.</p></td>
            <td><p class="normal">Commission Implementing Regulation (EU) 2018/150 <a id="ntc190-L_202501926EN.000302-E0190" href="#ntr190-L_202501926EN.000302-E0190">(<span class="oj-super oj-note-tag">190</span>)</a>.</p></td>
          </tr>
        </tbody></table>
        </body></html>
      HTML

      result = extract(html)
      expect(result.sections[1]).to include('Commission Implementing Regulation (EU) 2018/150.')
      expect(result.sections[1]).not_to include('(190)')
    end

    it 'preserves plain parenthetical numbers in prose that are not inside <sup>' do
      html = <<~HTML
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <p class="oj-ti-grseq-1">PART ONE</p>
        <p class="oj-ti-grseq-1"><span class="oj-bold">SCHEDULE OF CUSTOMS DUTIES</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">SECTION I</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">CHAPTER 10</span></p>
        <p class="oj-ti-annotation"><span class="oj-bold">Subheading notes</span></p>
        <table><tbody>
          <tr>
            <td><p class="normal">1.</p></td>
            <td><p class="normal">Triticum durum which have the same number (28) of chromosomes as that species.</p></td>
          </tr>
        </tbody></table>
        </body></html>
      HTML

      result = extract(html)
      expect(result.chapters['10']).to include('the same number (28) of chromosomes')
    end
  end

  describe 'content table extraction' do
    let(:chapter_with_content_table_html) do
      <<~HTML
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <p class="oj-ti-grseq-1">PART ONE</p>
        <p class="oj-ti-grseq-1"><span class="oj-bold">SCHEDULE OF CUSTOMS DUTIES</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">SECTION II</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">CHAPTER 11</span></p>
        <p class="oj-ti-annotation"><span class="oj-bold">Notes</span></p>
        <table><tbody>
          <tr>
            <td><p class="normal">2.</p></td>
            <td>
              <p class="oj-normal">(A) Products from the milling of the cereals listed in the table below fall in this chapter.</p>
              <p class="oj-normal">(B) Products falling in this chapter shall be classified in heading 1101 or 1102.</p>
              <table width="100%" border="0" class="oj-table"><tbody>
                <tr class="oj-table">
                  <td class="oj-table"><p class="oj-tbl-hdr">Cereal</p></td>
                  <td class="oj-table"><p class="oj-tbl-hdr">Starch content</p></td>
                  <td class="oj-table" colspan="2"><p class="oj-tbl-hdr">Rate of passage through a sieve with an aperture of</p></td>
                </tr>
                <tr class="oj-table">
                  <td class="oj-table"><p class="oj-normal"> </p></td>
                  <td class="oj-table"><p class="oj-normal"> </p></td>
                  <td class="oj-table"><p class="oj-tbl-hdr">315 micrometres (microns)</p></td>
                  <td class="oj-table"><p class="oj-tbl-hdr">500 micrometres (microns)</p></td>
                </tr>
                <tr class="oj-table">
                  <td class="oj-table"><p class="oj-tbl-hdr">(1)</p></td>
                  <td class="oj-table"><p class="oj-tbl-hdr">(2)</p></td>
                  <td class="oj-table"><p class="oj-tbl-hdr">(3)</p></td>
                  <td class="oj-table"><p class="oj-tbl-hdr">(4)</p></td>
                </tr>
                <tr class="oj-table">
                  <td class="oj-table"><p class="oj-tbl-txt">Wheat and rye</p></td>
                  <td class="oj-table"><p class="oj-tbl-txt">45 %</p></td>
                  <td class="oj-table"><p class="oj-tbl-txt">80 %</p></td>
                  <td class="oj-table"><p class="oj-tbl-txt">—</p></td>
                </tr>
                <tr class="oj-table">
                  <td class="oj-table"><p class="oj-tbl-txt">Maize (corn) and grain sorghum</p></td>
                  <td class="oj-table"><p class="oj-tbl-txt">45 %</p></td>
                  <td class="oj-table"><p class="oj-tbl-txt">—</p></td>
                  <td class="oj-table"><p class="oj-tbl-txt">90 %</p></td>
                </tr>
              </tbody></table>
            </td>
          </tr>
        </tbody></table>
        </body></html>
      HTML
    end

    it 'renders an oj-tbl-hdr/oj-tbl-txt table embedded in a chapter note as an indented markdown table' do
      result = extract(chapter_with_content_table_html)
      chapter = result.chapters['11']

      expect(chapter).to include('   | Cereal |')
      expect(chapter).to include('   | Wheat and rye |')
      expect(chapter).to include('   | Maize (corn) and grain sorghum |')
    end

    it 'merges a colspan header row with the sub-header row below it to form complete column labels' do
      result = extract(chapter_with_content_table_html)
      chapter = result.chapters['11']

      expect(chapter).to include('Rate of passage through a sieve with an aperture of 315 micrometres (microns)')
      expect(chapter).to include('Rate of passage through a sieve with an aperture of 500 micrometres (microns)')
    end

    it 'emits column-numbering rows like (1)(2)(3) as data rows below the markdown separator' do
      result = extract(chapter_with_content_table_html)
      chapter = result.chapters['11']

      lines = chapter.split("\n")
      separator_index = lines.index { |l| l.match?(/\A\s*\| ---/) }
      numbering_index = lines.index { |l| l.include?('| (1) |') }

      expect(separator_index).to be < numbering_index
    end
  end

  describe 'letter-list with nested oj-table inside a note cell (Ch74/75/76/80 pattern)' do
    # EU OJ XHTML for chapters like 74 wraps each letter-list item (a)/(b)/(c) in its own
    # two-column structural sub-table inside the note cell. Item (a)'s content cell then
    # contains an oj-table (oj-tbl-hdr/oj-tbl-txt) for the element composition table.
    # The shallow content_table? check must NOT flag the outer structural sub-table as a
    # content table (it would collapse everything into a single govspeak row). Instead:
    # - outer note table → extract_table_content
    # - each (a)/(b)/(c) structural sub-table → extract_table_content (not table_formatter)
    # - the inner oj-table inside (a) → table_formatter (correct)
    # First confirmed: Chapter 74, note 1 — refined copper composition table.

    let(:ch74_note_html) do
      <<~HTML
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <p class="oj-ti-grseq-1">PART ONE</p>
        <p class="oj-ti-grseq-1"><span class="oj-bold">SCHEDULE OF CUSTOMS DUTIES</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">SECTION XV</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">CHAPTER 74</span></p>
        <p class="oj-ti-annotation"><span class="oj-bold">Notes</span></p>
        <table><tbody>
          <tr>
            <td><p class="normal">1.</p></td>
            <td>
              <span>In this chapter, the following expressions have the meanings hereby assigned to them:</span>
              <table><tbody>
                <tr>
                  <td><p class="oj-normal">(a)</p></td>
                  <td>
                    <p class="oj-normal">Refined copper: Metal containing at least 99,85 % by weight of copper; or</p>
                    <p class="oj-ti-tbl">Other elements</p>
                    <table class="oj-table"><tbody>
                      <tr class="oj-table">
                        <td class="oj-table" colspan="2"><p class="oj-tbl-hdr">Element</p></td>
                        <td class="oj-table"><p class="oj-tbl-hdr">Limiting content % by weight</p></td>
                      </tr>
                      <tr class="oj-table">
                        <td class="oj-table"><p class="oj-tbl-txt">Ag</p></td>
                        <td class="oj-table"><p class="oj-tbl-txt">Silver</p></td>
                        <td class="oj-table"><p class="oj-tbl-txt">0,25</p></td>
                      </tr>
                      <tr class="oj-table">
                        <td class="oj-table"><p class="oj-tbl-txt">Zn</p></td>
                        <td class="oj-table"><p class="oj-tbl-txt">Zinc</p></td>
                        <td class="oj-table"><p class="oj-tbl-txt">1</p></td>
                      </tr>
                    </tbody></table>
                  </td>
                </tr>
              </tbody></table>
              <table><tbody>
                <tr>
                  <td><p class="oj-normal">(b)</p></td>
                  <td><p class="oj-normal">Copper alloys: Metallic substances in which copper predominates.</p></td>
                </tr>
              </tbody></table>
              <table><tbody>
                <tr>
                  <td><p class="oj-normal">(c)</p></td>
                  <td><p class="oj-normal">Master alloys: Alloys containing more than 10 % by weight of copper.</p></td>
                </tr>
              </tbody></table>
            </td>
          </tr>
        </tbody></table>
        </body></html>
      HTML
    end

    it 'extracts all letter-list items (a)/(b)/(c) — not just the one containing the oj-table' do
      result = extract(ch74_note_html)
      chapter = result.chapters['74']

      expect(chapter).to include('b) Copper alloys')
      expect(chapter).to include('c) Master alloys')
    end

    it 'renders the nested oj-table as a proper markdown table' do
      result = extract(ch74_note_html)
      chapter = result.chapters['74']

      expect(chapter).to include('| Ag |')
      expect(chapter).to include('| Zn |')
      expect(chapter).to include('| Element |')
      expect(chapter).not_to include('Ag Silver 0,25')
    end

    it 'renders letter-list label as a govspeak list marker, not a govspeak table cell' do
      result = extract(ch74_note_html)
      chapter = result.chapters['74']

      expect(chapter).not_to include('| (a) |')
      expect(chapter).not_to include('| a) |')
      expect(chapter).to include('a) Refined copper')
    end
  end

  describe 'Additional Notes parenthetical label with numeric sub-items only (no intro text)' do
    # EU OJ XHTML: "(h)" row whose content cell contains ONLY a sub-table with rows
    # "1." and "2." (no introductory <p> text). The extractor must emit "(h)" on its
    # own line followed by "1." and "2." as indented numbered items at 6 spaces, not
    # collapse them into "(h) 1. item text" on a single line.
    # First confirmed: Chapter 02 Additional Notes 1.A.(h).

    let(:parenthetical_with_numeric_sub_items_html) do
      <<~HTML
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <p class="oj-ti-grseq-1">PART ONE</p>
        <p class="oj-ti-grseq-1"><span class="oj-bold">SCHEDULE OF CUSTOMS DUTIES</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">SECTION I</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">CHAPTER 2</span></p>
        <p class="oj-ti-annotation"><span class="oj-bold">Note</span></p>
        <table><tbody>
          <tr><td><p class="oj-normal">1.</p></td><td><p class="oj-normal">This chapter does not cover insects.</p></td></tr>
        </tbody></table>
        <p class="oj-ti-annotation">Additional notes</p>
        <table><tbody>
          <tr>
            <td><p class="oj-normal">(g)</p></td>
            <td><p class="oj-normal">'separated hindquarters': the rear part of a half-carcase.</p></td>
          </tr>
          <tr>
            <td><p class="oj-normal">(h)</p></td>
            <td>
              <table><tbody>
                <tr>
                  <td><p class="oj-normal">1.</p></td>
                  <td><p class="oj-normal">'crop' and 'chuck and blade' cuts: the dorsal part of the forequarter.</p></td>
                </tr>
                <tr>
                  <td><p class="oj-normal">2.</p></td>
                  <td><p class="oj-normal">'brisket' cut: the lower part of the forequarter.</p></td>
                </tr>
              </tbody></table>
            </td>
          </tr>
        </tbody></table>
        </body></html>
      HTML
    end

    it 'emits (h) on its own line, not merged with the first numeric sub-item' do
      chapter = extract(parenthetical_with_numeric_sub_items_html).chapters['02']
      lines = chapter.split("\n")
      h_line = lines.find { |l| l.strip == '(h)' }
      expect(h_line).to be_present
    end

    it 'places numeric sub-items at 6 spaces (inside (h), not inline with it)' do
      chapter = extract(parenthetical_with_numeric_sub_items_html).chapters['02']
      lines = chapter.split("\n")
      item1 = lines.find { |l| l.include?("'crop' and 'chuck and blade' cuts") }
      item2 = lines.find { |l| l.include?("'brisket' cut") }
      expect(item1).to be_present
      expect(item2).to be_present
      expect(item1[/\A( *)/, 1].length).to eq(6)
      expect(item2[/\A( *)/, 1].length).to eq(6)
    end

    it 'places (g) with its own content inline (parenthetical with text, not a sub-table)' do
      chapter = extract(parenthetical_with_numeric_sub_items_html).chapters['02']
      lines = chapter.split("\n")
      g_line = lines.find { |l| l.include?("'separated hindquarters'") }
      expect(g_line).to be_present
      expect(g_line).to include('(g)')
    end
  end

  describe '<span> with inline italic children as a text container (not structural wrapper)' do
    # EU OJ XHTML wraps a paragraph in a top-level <span> where the only element children
    # are inline formatting spans like <span class="oj-italic">. The structural-wrapper
    # check must NOT fire here (no <table> children) — the entire span should be treated
    # as a text container and all text (including species names in italics) extracted.
    # First confirmed: Chapter 03 Additional Notes 1 — "cod fillets (Gadus morhua, Gadus
    # ogac, Gadus macrocephalus) having a total salt content..." was losing its main
    # sentence and returning only the three italic species names.

    let(:italic_span_html) do
      <<~HTML
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <p class="oj-ti-grseq-1">PART ONE</p>
        <p class="oj-ti-grseq-1"><span class="oj-bold">SCHEDULE OF CUSTOMS DUTIES</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">SECTION I</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">CHAPTER 3</span></p>
        <p class="oj-ti-annotation"><span class="oj-bold">Note</span></p>
        <table><tbody>
          <tr><td><p class="oj-normal">1.</p></td><td><p class="oj-normal">This chapter does not cover insects.</p></td></tr>
        </tbody></table>
        <p class="oj-ti-annotation">Additional notes</p>
        <table><tbody>
          <tr>
            <td><p class="oj-normal">1.</p></td>
            <td>
              <span>For the purposes of subheadings 0305 32 11 and 0305 32 19, cod fillets (<span class="oj-italic">Gadus morhua</span>, <span class="oj-italic">Gadus ogac</span>, <span class="oj-italic">Gadus macrocephalus</span>) having a total salt content by weight of 12 % or more are considered to be salted fish.</span>
              <p class="oj-normal">However, frozen cod fillets which have a total salt content by weight of less than 12 % are to be classified under subheadings 0304 71 10 and 0304 71 90.</p>
            </td>
          </tr>
        </tbody></table>
        </body></html>
      HTML
    end

    it 'extracts the full sentence from the outer span, including text around italic species names' do
      chapter = extract(italic_span_html).chapters['03']
      expect(chapter).to include('For the purposes of subheadings 0305 32 11')
      expect(chapter).to include('Gadus morhua')
      expect(chapter).to include('Gadus macrocephalus')
      expect(chapter).to include('are considered to be salted fish')
    end

    it 'does not lose the However paragraph that follows the outer span' do
      chapter = extract(italic_span_html).chapters['03']
      expect(chapter).to include('However, frozen cod fillets')
      expect(chapter).to include('0304 71 10')
    end

    it 'keeps the sentence and the species names on the same block, not as three separate lines' do
      chapter = extract(italic_span_html).chapters['03']
      lines = chapter.split("\n").reject(&:empty?)
      morhua_line = lines.find { |l| l.include?('Gadus morhua') }
      expect(morhua_line).to include('For the purposes of subheadings')
    end
  end

  describe 'text-only <span> as intro sentence before sub-item tables' do
    # EU OJ XHTML wraps intro text in a plain <span> (no element children) followed
    # by sibling <table> elements for each sub-item. The extractor must treat the
    # text-only span as a paragraph (extract its text) and the sibling tables as
    # indented sub-items — not collapse everything or drop the intro.
    # First confirmed: Chapter 11 note 3, Additional Notes 1 and 2.

    let(:intro_span_html) do
      <<~HTML
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <p class="oj-ti-grseq-1">PART ONE</p>
        <p class="oj-ti-grseq-1"><span class="oj-bold">SCHEDULE OF CUSTOMS DUTIES</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">SECTION II</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">CHAPTER 11</span></p>
        <p class="oj-ti-annotation"><span class="oj-bold">Notes</span></p>
        <table><tbody>
          <tr>
            <td><p class="normal">3.</p></td>
            <td>
              <span>For the purposes of heading 1103, the terms mean products obtained by the fragmentation of cereal grains, of which:</span>
              <table><tbody>
                <tr>
                  <td><p class="oj-normal">(a)</p></td>
                  <td><p class="oj-normal">in the case of maize products, at least 95 % by weight passes through a sieve.</p></td>
                </tr>
              </tbody></table>
              <table><tbody>
                <tr>
                  <td><p class="oj-normal">(b)</p></td>
                  <td><p class="oj-normal">in the case of other cereal products, at least 95 % by weight passes through a sieve.</p></td>
                </tr>
              </tbody></table>
            </td>
          </tr>
        </tbody></table>
        <p class="oj-ti-annotation">Additional notes</p>
        <table><tbody>
          <tr>
            <td><p class="normal">1.</p></td>
            <td>
              <span>The duty-rate applicable to mixtures of this chapter shall be as follows:</span>
              <table><tbody>
                <tr>
                  <td><p class="oj-normal">(a)</p></td>
                  <td><p class="oj-normal">in mixtures where one component is at least 90 %, that rate applies;</p></td>
                </tr>
              </tbody></table>
              <table><tbody>
                <tr>
                  <td><p class="oj-normal">(b)</p></td>
                  <td><p class="oj-normal">in other mixtures, the highest rate applies.</p></td>
                </tr>
              </tbody></table>
            </td>
          </tr>
        </tbody></table>
        </body></html>
      HTML
    end

    it 'preserves the intro sentence from a text-only <span> before chapter-note sub-item tables' do
      chapter = extract(intro_span_html).chapters['11']
      expect(chapter).to include('For the purposes of heading 1103')
      expect(chapter).to include('in the case of maize products')
      expect(chapter).to include('in the case of other cereal products')
    end

    it 'does not lose the intro sentence from a text-only <span> in Additional Notes' do
      sections = extract(intro_span_html)
      chapter = sections.chapters['11']
      expect(chapter).to include('The duty-rate applicable to mixtures')
      expect(chapter).to include('in mixtures where one component')
      expect(chapter).to include('in other mixtures')
    end

    it 'places the intro sentence before the (a)/(b) sub-items in chapter notes' do
      chapter = extract(intro_span_html).chapters['11']
      intro_idx = chapter.index('For the purposes of heading 1103')
      a_idx     = chapter.index('in the case of maize products')
      expect(intro_idx).to be < a_idx
    end

    it 'places the intro sentence before the (a)/(b) sub-items in Additional Notes' do
      chapter = extract(intro_span_html).chapters['11']
      intro_idx = chapter.index('The duty-rate applicable to mixtures')
      a_idx     = chapter.index('in mixtures where one component')
      expect(intro_idx).to be < a_idx
    end
  end

  describe 'nested (A)/(B) chapter note with (a)/(b) sub-items inside a <span> wrapper' do
    let(:nested_ab_html) do
      <<~HTML
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <p class="oj-ti-grseq-1">PART ONE</p>
        <p class="oj-ti-grseq-1"><span class="oj-bold">SCHEDULE OF CUSTOMS DUTIES</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">SECTION II</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">CHAPTER 11</span></p>
        <p class="oj-ti-annotation"><span class="oj-bold">Notes</span></p>
        <table><tbody>
          <tr>
            <td><p class="normal">2.</p></td>
            <td>
              <span>
                <table><tbody>
                  <tr>
                    <td><p class="oj-normal">(A)</p></td>
                    <td>
                      <p class="oj-normal">Products from the milling of the cereals listed in the table below fall in this chapter if they have:</p>
                      <table><tbody>
                        <tr>
                          <td><p class="oj-normal">(a)</p></td>
                          <td><p class="oj-normal">a starch content exceeding that indicated in column 2; and</p></td>
                        </tr>
                      </tbody></table>
                      <table><tbody>
                        <tr>
                          <td><p class="oj-normal">(b)</p></td>
                          <td><p class="oj-normal">an ash content not exceeding that indicated in column 3.</p></td>
                        </tr>
                      </tbody></table>
                      <p class="oj-normal">Otherwise, they fall in heading 2302.</p>
                    </td>
                  </tr>
                </tbody></table>
                <table><tbody>
                  <tr>
                    <td><p class="oj-normal">(B)</p></td>
                    <td>
                      <p class="oj-normal">Products falling in this chapter shall be classified in heading 1101.</p>
                      <p class="oj-normal">Otherwise, they fall in heading 1103.</p>
                    </td>
                  </tr>
                </tbody></table>
              </span>
            </td>
          </tr>
        </tbody></table>
        </body></html>
      HTML
    end

    it 'extracts (A) and (B) as separate blocks, not as a single collapsed paragraph' do
      chapter = extract(nested_ab_html).chapters['11']
      expect(chapter).to include('(A) Products from the milling')
      expect(chapter).to include('(B) Products falling in this chapter')
      # Both markers must be present — if they were collapsed into one paragraph
      # the (B) marker would appear inline without a preceding blank line.
      ab_index = chapter.index('(A)')
      bb_index = chapter.index('(B)')
      expect(bb_index).to be > ab_index
      expect(chapter[ab_index...bb_index]).to include("\n\n")
    end

    it 'places (a) and (b) sub-items as indented list items under (A)' do
      chapter = extract(nested_ab_html).chapters['11']
      lines = chapter.split("\n")
      a_line = lines.find { |l| l.include?('a starch content exceeding') }
      b_line = lines.find { |l| l.include?('an ash content not exceeding') }
      expect(a_line).to be_present
      expect(b_line).to be_present
      expect(a_line[/\A( *)/, 1].length).to be > 0
      expect(b_line[/\A( *)/, 1].length).to be > 0
    end

    it 'places "Otherwise" continuation paragraphs as their own indented lines (not collapsed into the sub-list)' do
      chapter = extract(nested_ab_html).chapters['11']
      lines = chapter.split("\n")
      otherwise_lines = lines.select { |l| l.include?('Otherwise') }
      expect(otherwise_lines).not_to be_empty
      otherwise_lines.each do |line|
        expect(line[/\A( *)/, 1].length).to be > 0
      end
    end

    it 'places (B) as a separate indented block after (A) (not collapsed into (A))' do
      chapter = extract(nested_ab_html).chapters['11']
      lines = chapter.split("\n")
      b_line = lines.find { |l| l.match?(/\A\s+\(B\)/) }
      expect(b_line).to be_present
      expect(b_line[/\A( *)/, 1].length).to be > 0
    end
  end

  describe 'GRI extraction' do
    it 'extracts numbered rules keyed by rule number string' do
      result = extract(gri_only_html)
      expect(result.general_rules['1']).to eq 'Classification shall be determined according to the terms of the headings.'
      expect(result.general_rules['2']).to eq 'Any reference in a heading to an article shall be taken to include a reference to that article.'
    end

    it 'returns empty sections and chapters when there is no Part Two' do
      result = extract(gri_only_html)
      expect(result.sections).to be_empty
      expect(result.chapters).to be_empty
    end
  end

  describe 'section note extraction' do
    it 'extracts section notes with integer keys' do
      result = extract(full_fixture_html)
      expect(result.sections[1]).to include('This section does not cover goods of Chapter 1.')
    end

    it 'includes the second note with its intro text' do
      result = extract(full_fixture_html)
      expect(result.sections[1]).to include('In this section the following expressions apply:')
    end

    it 'indents sub-items with 4 spaces and converts (a)/(b) to a)/b) form' do
      # Section notes go through format_chapter_part which applies normalise_list_marker,
      # converting (a)→a) consistent with chapter notes govspeak convention.
      result = extract(full_fixture_html)
      expect(result.sections[1]).to include('    a) First sub-item text.')
      expect(result.sections[1]).to include('    b) Second sub-item text.')
    end

    it 'emits a ### Additional Notes heading when Additional Notes appears after the main section notes' do
      # Sections 16 and 17 have Additional Notes following the main numbered notes.
      # handle_collecting_section must inject the heading when it encounters the annotation header.
      html = <<~HTML
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <p class="oj-ti-grseq-1">PART ONE</p>
        <p class="oj-ti-grseq-1"><span class="oj-bold">SCHEDULE OF CUSTOMS DUTIES</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">SECTION XVI</span></p>
        <p class="oj-ti-annotation"><span class="oj-bold">Notes</span></p>
        <table><tbody>
          <tr><td><p class="oj-normal">1.</p></td><td><p class="oj-normal">This section does not cover transmission belts.</p></td></tr>
        </tbody></table>
        <p class="oj-ti-annotation">Additional Notes</p>
        <table><tbody>
          <tr><td><p class="oj-normal">1.</p></td><td><p class="oj-normal">Tools necessary for maintenance are to be classified with those machines.</p></td></tr>
          <tr><td><p class="oj-normal">2.</p></td><td><p class="oj-normal">The declarant shall produce an illustrated document.</p></td></tr>
        </tbody></table>
        </body></html>
      HTML

      result = extract(html)
      section = result.sections[16]
      expect(section).to include('### Additional Notes')
      expect(section).to include('Tools necessary for maintenance')
      expect(section).to include('The declarant shall produce')
      expect(section.index('### Additional Notes')).to be > section.index('This section does not cover')
    end

    it 'emits a ### Subheading notes heading when Subheading Notes appears after the main section notes' do
      # Section 11 has Subheading Notes following the main numbered notes.
      # handle_collecting_section must inject the heading when it encounters the annotation header.
      html = <<~HTML
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <p class="oj-ti-grseq-1">PART ONE</p>
        <p class="oj-ti-grseq-1"><span class="oj-bold">SCHEDULE OF CUSTOMS DUTIES</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">SECTION XI</span></p>
        <p class="oj-ti-annotation"><span class="oj-bold">Notes</span></p>
        <table><tbody>
          <tr><td><p class="oj-normal">1.</p></td><td><p class="oj-normal">This section does not cover animal brush-making bristles.</p></td></tr>
        </tbody></table>
        <p class="oj-ti-annotation">Subheading Notes</p>
        <table><tbody>
          <tr><td><p class="oj-normal">1.</p></td><td><p class="oj-normal">In this section the expression 'unbleached yarn' means yarn which has the natural colour of its constituent fibres.</p></td></tr>
          <tr><td><p class="oj-normal">2.</p></td><td><p class="oj-normal">Products of Chapters 56 to 63 containing two or more textile materials are to be regarded as consisting wholly of that textile material.</p></td></tr>
        </tbody></table>
        </body></html>
      HTML

      result = extract(html)
      section = result.sections[11]
      expect(section).to include('### Subheading notes')
      expect(section).to include('unbleached yarn')
      expect(section).to include('Products of Chapters 56 to 63')
      expect(section.index('### Subheading notes')).to be > section.index('This section does not cover')
    end
  end

  describe 'chapter note extraction' do
    it 'extracts chapter notes with zero-padded two-character string keys' do
      result = extract(full_fixture_html)
      expect(result.chapters['01']).to include('This chapter covers all live animals.')
    end

    it 'includes additional notes under the ### Additional Notes heading' do
      result = extract(full_fixture_html)
      expect(result.chapters['01']).to include('### Additional Notes')
      expect(result.chapters['01']).to include('For the purposes of subheading 0101 21')
    end

    it 'does not include the commodity table content' do
      result = extract(full_fixture_html)
      expect(result.chapters['01']).not_to include('0101000000')
      expect(result.chapters['01']).not_to include('Live horses')
    end

    it 'recognises an "Additional notes" heading that carries a footnote superscript as the additional notes separator' do
      # EU OJ XHTML appends footnote references (<a href="#ntr97-...">(<span>97</span>)</a>)
      # followed by a non-breaking space (&nbsp;, U+00A0) directly inside the annotation <p>.
      # node.text.strip returns "Additional notes (97)" — doesn't match ADDITIONAL_NOTES_PATTERN.
      # paragraph_text_without_footnotes strips the <a href="#ntr..."> nodes AND normalises
      #   (which Ruby's \s does not match) so the heading text matches correctly.
      # First confirmed: Chapter 27 "Additional notes" heading with footnote (97).
      html = <<~HTML
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <p class="oj-ti-grseq-1">PART ONE</p>
        <p class="oj-ti-grseq-1"><span class="oj-bold">SCHEDULE OF CUSTOMS DUTIES</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">SECTION V</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">CHAPTER 27</span></p>
        <p class="oj-ti-annotation"><span class="oj-bold">Notes</span></p>
        <table><tbody>
          <tr><td><p class="normal">1.</p></td><td><p class="normal">This chapter does not cover separate chemically defined compounds.</p></td></tr>
        </tbody></table>
        <p class="oj-ti-annotation">Subheading notes</p>
        <table><tbody>
          <tr><td><p class="normal">1.</p></td><td><p class="normal">For the purposes of subheading 2701 11.</p></td></tr>
        </tbody></table>
        <p class="oj-ti-annotation" id="d1e60582-3-1"><span class="oj-bold">Additional notes</span><a id="ntc97-L_202501926EN.000302-E0097" href="#ntr97-L_202501926EN.000302-E0097">(<span class="oj-super oj-note-tag">97</span>)</a>&#160;</p>
        <table><tbody>
          <tr><td><p class="normal">1.</p></td><td><p class="normal">For the purposes of subheading 2707 99 80.</p></td></tr>
        </tbody></table>
        </body></html>
      HTML

      result = extract(html)
      chapter = result.chapters['27']

      expect(chapter).to include('### Additional Notes')
      expect(chapter).to include('For the purposes of subheading 2707 99 80.')
      expect(chapter.index('### Subheading notes')).to be < chapter.index('### Additional Notes')
    end

    it 'emits a ### Subheading notes heading when the annotation header is Subheading notes' do
      html = <<~HTML
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <p class="oj-ti-grseq-1">PART ONE</p>
        <p class="oj-ti-grseq-1"><span class="oj-bold">SCHEDULE OF CUSTOMS DUTIES</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">SECTION I</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">CHAPTER 4</span></p>
        <p class="oj-ti-annotation"><span class="oj-bold">Notes</span></p>
        <table><tbody>
          <tr><td><p class="normal">6.</p></td><td><p class="normal">For the purposes of heading 0410.</p></td></tr>
        </tbody></table>
        <p class="oj-ti-annotation">Subheading notes</p>
        <table><tbody>
          <tr><td><p class="normal">1.</p></td><td><p class="normal">For the purposes of subheading 0404 10.</p></td></tr>
          <tr><td><p class="normal">2.</p></td><td><p class="normal">For the purposes of subheading 0405 10.</p></td></tr>
        </tbody></table>
        <p class="oj-ti-annotation">Additional notes</p>
        <table><tbody>
          <tr><td><p class="normal">1.</p></td><td><p class="normal">The duty rate applicable to mixtures.</p></td></tr>
        </tbody></table>
        </body></html>
      HTML

      result = extract(html)
      chapter = result.chapters['04']
      expect(chapter).to include('### Subheading notes')
      expect(chapter).to include('For the purposes of subheading 0404 10.')
      expect(chapter).to include('For the purposes of subheading 0405 10.')
      expect(chapter.index('### Subheading notes')).to be < chapter.index('### Additional Notes')
    end

    it 'emits a ### Subheading notes heading when Subheading notes is the first annotation for a chapter' do
      # Chapters 75-80 have no regular Notes section — Subheading notes is the first
      # annotation header encountered. The fix ensures handle_in_chapter injects the
      # heading when it transitions to :collecting_chapter, not only handle_collecting_chapter.
      html = <<~HTML
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml"><body>
        <p class="oj-ti-grseq-1">PART ONE</p>
        <p class="oj-ti-grseq-1"><span class="oj-bold">SCHEDULE OF CUSTOMS DUTIES</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">SECTION XV</span></p>
        <p class="oj-ti-grseq-1"><span class="oj-italic">CHAPTER 75</span></p>
        <p class="oj-ti-annotation">Subheading notes</p>
        <table><tbody>
          <tr><td><p class="normal">1.</p></td><td><p class="normal">For the purposes of subheading 7501 10.</p></td></tr>
        </tbody></table>
        <p class="oj-ti-annotation">Additional notes</p>
        <table><tbody>
          <tr><td><p class="normal">1.</p></td><td><p class="normal">The duty rate applicable to nickel mattes.</p></td></tr>
        </tbody></table>
        </body></html>
      HTML

      result = extract(html)
      chapter = result.chapters['75']
      expect(chapter).to include('### Subheading notes')
      expect(chapter).to include('For the purposes of subheading 7501 10.')
      expect(chapter.index('### Subheading notes')).to be < chapter.index('### Additional Notes')
    end
  end
end
