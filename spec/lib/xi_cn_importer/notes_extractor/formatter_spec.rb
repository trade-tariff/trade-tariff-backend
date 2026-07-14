require 'rails_helper'

RSpec.describe XiCnImporter::NotesExtractor::Formatter do
  subject(:formatter) { described_class.new }

  describe '#call' do
    it 'returns blank content unchanged' do
      expect(formatter.call('')).to eq('')
      expect(formatter.call(nil)).to be_nil
    end

    # ══════════════════════════════════════════════════════════════════════════
    # Chapter-notes section rules
    # (content before "### Additional Notes")
    # ══════════════════════════════════════════════════════════════════════════

    # ── Rule: (a) → a) list marker normalisation ─────────────────────────────
    # EU source uses (a)/(b)/(c) style; govspeak expects a)/b)/c) in chapter notes.
    # First confirmed: Chapter 01

    it 'converts indented (a)/(b)/(c) markers to a)/b)/c) style in chapter notes' do
      input = <<~TEXT
        1. This chapter covers all live animals, except:

            (a) first item;

            (b) second item; and

            (c) third item.
      TEXT

      expected = <<~TEXT
        1. This chapter covers all live animals, except:

            a) first item;

            b) second item; and

            c) third item.
      TEXT

      expect(formatter.call(input.chomp)).to eq(expected.chomp)
    end

    it 'converts multi-character roman-numeral markers (i)/(ii)/(iii) to i)/ii)/iii) style' do
      input = "    (i) first;\n\n    (ii) second;\n\n    (iii) third."
      expected = "    i) first;\n\n    ii) second;\n\n    iii) third."
      expect(formatter.call(input)).to eq(expected)
    end

    it 'does not convert (a) markers that appear mid-sentence' do
      input = 'The provisions of paragraph (a) apply here.'
      expect(formatter.call(input)).to eq(input)
    end

    # ── Rule: merge dangling note-number+marker lines with their content ──────
    # EU XHTML can place the note number ("6.") in the label cell and "(a)" as
    # the cell content, with the actual (a) text in the NEXT row (empty label).
    # This produces "6. (a)" alone on a line followed by the text on the next.
    # Govspeak needs them on the same line. Handled in chapter notes by
    # merge_trailing_list_markers; in Additional Notes by an extended ISOLATED_MARKER_PATTERN.

    it 'merges a note-number+marker line with the following content in chapter notes' do
      # "6. (a)" is a dangling marker — its content is in the next extractor row.
      # "(b)" already has its content on the same line (no merge needed).
      input = [
        '6. (a)',
        '',
        '   Uncooked seasoned meats fall in Chapter 16.',
        '',
        '   (b) Products falling in heading 0210.',
      ].join("\n")

      expected = [
        '6. a) Uncooked seasoned meats fall in Chapter 16.',
        '',
        '   b) Products falling in heading 0210.',
      ].join("\n")

      expect(formatter.call(input)).to eq(expected)
    end

    it 'merges a bare isolated (a) marker with the following content in chapter notes' do
      input = "Some lead-in:\n\n(a)\n\nfirst item;\n\n(b) second item."
      expected = "Some lead-in:\n\na) first item;\n\nb) second item."
      expect(formatter.call(input)).to eq(expected)
    end

    # ── Rule: align orphaned first list item to match sibling indent ──────────
    # EU XHTML for some notes (e.g. Chapter 04 note 5) emits the first sub-list
    # item at 0 indent while all subsequent siblings are at 4 spaces. After
    # normalise_list_marker converts (a)→a), the 0-indent marker is detected and
    # raised to match the indent of the next list item.
    # First confirmed: Chapter 04 chapter notes, note 5 item (a).

    it 'aligns a misindented first list item with the indent of subsequent sibling items' do
      input = [
        '5. This chapter does not cover:',
        '',
        '(a) non-living insects (heading 0511);',
        '',
        '    (b) products obtained from whey (heading 1702);',
        '',
        '    (c) products from milk (heading 1901);',
        '',
        '    (d) albumins (heading 3502).',
      ].join("\n")

      expected = [
        '5. This chapter does not cover:',
        '',
        '    a) non-living insects (heading 0511);',
        '',
        '    b) products obtained from whey (heading 1702);',
        '',
        '    c) products from milk (heading 1901);',
        '',
        '    d) albumins (heading 3502).',
      ].join("\n")

      expect(formatter.call(input)).to eq(expected)
    end

    # ── Rule: merge continuation clauses at 0 indent with the preceding list item ─
    # EU XHTML can split a list item's sentence across two table rows: the item text
    # (ending with a comma) in one row and a continuation clause at 0 indent in the
    # next row. Merge the continuation back onto the list item.
    # First confirmed: Chapter 08 chapter notes note 3, item (b) — the clause
    # "provided that they retain the character of dried fruit or dried nuts." was
    # arriving at 0 indent after the b) item row.

    it 'merges a continuation clause at 0 indent with the preceding comma-terminated list item' do
      input = [
        '3. Dried fruit may be treated for the following purposes:',
        '',
        '    (a) for additional preservation (for example, by sulphuring),',
        '',
        '    (b) to improve or maintain their appearance (for example, by the addition of vegetable oil),',
        '',
        'provided that they retain the character of dried fruit.',
        '',
        '4. Heading 0812 applies to fruit and nuts.',
      ].join("\n")

      expected = [
        '3. Dried fruit may be treated for the following purposes:',
        '',
        '    a) for additional preservation (for example, by sulphuring),',
        '',
        '    b) to improve or maintain their appearance (for example, by the addition of vegetable oil), provided that they retain the character of dried fruit.',
        '',
        '4. Heading 0812 applies to fruit and nuts.',
      ].join("\n")

      expect(formatter.call(input)).to eq(expected)
    end

    # ── Rule: indent continuation paragraphs that follow a chapter-note list ──
    # EU XHTML can emit a note's closing paragraph at 0 indent after the list it
    # supplements. Govspeak needs it at the same indent as the list items so it
    # reads as part of the numbered note. Unlike the comma-terminated case
    # (merge_list_item_continuations), the last list item ends with a full stop and
    # the continuation is a structurally separate paragraph.
    # First confirmed: Chapter 09 chapter notes, note 1.

    it 'indents a continuation paragraph at 0 indent to match the preceding list indent' do
      input = [
        '1. Mixtures are to be classified as follows:',
        '',
        '    (a) mixtures of two or more of the same heading;',
        '',
        '    (b) mixtures of different headings are classified in heading 0910.',
        '',
        'The addition of other substances shall not affect their classification.',
        '',
        '2. This chapter does not cover cubeb pepper.',
      ].join("\n")

      expected = [
        '1. Mixtures are to be classified as follows:',
        '',
        '    a) mixtures of two or more of the same heading;',
        '',
        '    b) mixtures of different headings are classified in heading 0910.',
        '',
        '    The addition of other substances shall not affect their classification.',
        '',
        '2. This chapter does not cover cubeb pepper.',
      ].join("\n")

      expect(formatter.call(input)).to eq(expected)
    end

    it 'does not indent a numbered note that follows a list' do
      input = [
        '1. This chapter covers:',
        '',
        '    (a) item one;',
        '',
        '    (b) item two.',
        '',
        '2. This chapter does not cover.',
      ].join("\n")

      expected = [
        '1. This chapter covers:',
        '',
        '    a) item one;',
        '',
        '    b) item two.',
        '',
        '2. This chapter does not cover.',
      ].join("\n")

      expect(formatter.call(input)).to eq(expected)
    end

    # ── Rule: raise pre-list continuation paragraphs to 3 spaces ─────────────────
    # EU XHTML can emit a note's continuation sentence at 0 indent *before* the
    # sub-list it introduces. list_indent is 0 at that point (no items seen yet),
    # so the post-list raise doesn't fire. Govspeak needs the sentence at 3 spaces
    # so the ordered-list counter is not reset and the sub-items don't render as a
    # code block. First confirmed: Chapter 12 notes 3 and 4.

    it 'raises a pre-list continuation paragraph to 3 spaces inside a numbered note' do
      input = [
        '3. For the purposes of heading 1209, beet seeds are seeds of a kind used for sowing.',
        '',
        'Heading 1209 does not, however, apply to the following, even if for sowing:',
        '',
        '    a) leguminous vegetables;',
        '',
        '    b) spices.',
        '',
        '4. Heading 1211 applies to basil.',
        '',
        'Heading 1211 does not, however, apply to:',
        '',
        '    a) medicaments.',
        '',
        '5. For the purposes of heading 1212.',
      ].join("\n")

      result = formatter.call(input)

      expect(result).to include('   Heading 1209 does not, however, apply to the following, even if for sowing:')
      expect(result).to include('   Heading 1211 does not, however, apply to:')
      expect(result).to include('3. For the purposes of heading 1209')
      expect(result).to include('5. For the purposes of heading 1212.')
    end

    # ── Rule: two-digit note continuation indent ─────────────────────────────
    # Govspeak requires continuation paragraphs to be indented to the content-
    # start column of the enclosing list item. For "10. text" that is 4 spaces
    # (not 3). Without this, govspeak restarts the ordered-list counter at 11.
    # EU XHTML sometimes emits these continuation paragraphs at 3 spaces which
    # our pre-processing leaves untouched; we must raise them to 4.
    # First confirmed: Chapter 84, Note 10 → Note 11.

    it 'raises a continuation paragraph at 3 spaces to 4 spaces inside a two-digit note' do
      input = [
        '10. For the purposes of heading 8485, the expression means the formation of objects.',
        '',
        '   Subject to note 1 to Section XVI and note 1 to Chapter 84, machines are classified.',
        '',
        '11. Next note.',
      ].join("\n")

      result = formatter.call(input)

      expect(result).to include("\n    Subject to note 1 to Section XVI")
      expect(result).to include('11. Next note.')
      expect(result).not_to include("\n   Subject to note 1")
    end

    it 'still raises 0-indent continuation to 3 spaces inside a single-digit note' do
      input = [
        '3. This heading covers products.',
        '',
        'However, it does not cover excluded items.',
        '',
        '4. Next note.',
      ].join("\n")

      result = formatter.call(input)

      expect(result).to include('   However, it does not cover excluded items.')
      expect(result).to include('4. Next note.')
    end

    it 'raises a letter sub-list at 3 spaces to 4 spaces inside a two-digit note' do
      # Chapter 22 note 12: sub-list items (a)-(f) arrive at 3 spaces under a two-digit
      # note, not indented enough for govspeak (which needs 4 to continue the ordered list).
      # Without this, note 13 starts a new <ol> and the browser renders it as "1.".
      input = [
        '12. Subheading 2207 20 covers mixtures denatured with one or more of the following:',
        '',
        '   a) automotive petrol;',
        '',
        '   b) tert-butyl ethyl ether;',
        '',
        '   c) methyl tert-butylether.',
        '',
        '   The denaturants referred to in points (b) and (c) must be used in combination.',
        '',
        '13. For the purposes of subheadings 2202 99 11.',
      ].join("\n")

      result = formatter.call(input)

      expect(result).to include('    a) automotive petrol;')
      expect(result).to include('    b) tert-butyl ethyl ether;')
      expect(result).to include('    c) methyl tert-butylether.')
      expect(result).to include('    The denaturants referred to')
      expect(result).to include('13. For the purposes of subheadings')
      expect(result).not_to include("\n   a) automotive petrol")
    end

    it 'does not raise a list marker at 0 indent to 3 spaces when it is the pre-list item' do
      input = [
        '6. This note covers:',
        '',
        'a) item one;',
        '',
        'b) item two.',
        '',
        '7. Next note.',
      ].join("\n")

      result = formatter.call(input)

      expect(result).not_to include('   a) item one;')
      expect(result).to include('7. Next note.')
    end

    # ── Rule: normalise deep numeric sub-items to the enclosing letter-list indent ─
    # EU XHTML nests (1)/(2) sub-items one table level deeper than the enclosing a)/b)
    # letter-list, producing 8-space indentation when the letter-list is at 4 spaces.
    # At 8 spaces they can render as a code block or deeply nested item in govspeak.
    # Normalise them to list_indent (matching the enclosing letter-list).
    # First confirmed: Chapter 19 note 2, sub-items under b).

    it 'normalises numeric sub-items deeper than the letter-list to the letter-list indent' do
      input = [
        '2. For the purposes of heading 1901:',
        '',
        "    a) the term 'groats' means cereal groats of Chapter 11;",
        '',
        "    b) the terms 'flour' and 'meal' mean:",
        '',
        '        (1) cereal flour and meal of Chapter 11, and',
        '',
        '        (2) flour, meal and powder of vegetable origin.',
        '',
        '3. Heading 1904 does not cover.',
      ].join("\n")

      result = formatter.call(input)

      expect(result).to include("    a) the term 'groats' means cereal groats of Chapter 11;")
      expect(result).to include("    b) the terms 'flour' and 'meal' mean:")
      expect(result).to include('    (1) cereal flour and meal of Chapter 11, and')
      expect(result).to include('    (2) flour, meal and powder of vegetable origin.')
      expect(result).to include('3. Heading 1904 does not cover.')
    end

    # ── Rule: em-dash sub-bullets under a letter-list item → hyphen at letter-list indent ─
    # EU XHTML nests em-dash (—) sub-bullets in a two-column sub-table inside the letter-list
    # item cell, producing "        — content" at 8 spaces (depth = 2) when the letter-list
    # is at 4 spaces (depth = 1). convert_emdash_bullet (now also in format_main_part)
    # converts — to - , and indent_note_continuations pulls the resulting "- " items
    # back to list_indent (4 spaces), matching the letter-list level.
    # First confirmed: Chapter 59 notes 5 and 8.

    it 'converts em-dash sub-bullets under a letter-list item to hyphens at the letter-list indent' do
      input = [
        "5. For the purposes of heading 5906, the expression 'rubberised textile fabrics' means:",
        '',
        '    a) textile fabrics impregnated, coated, covered or laminated with rubber:',
        '',
        '        — weighing not more than 1 500 g/m2, or',
        '',
        '        — weighing more than 1 500 g/m2 and containing more than 50 % by weight of textile material;',
        '',
        '    b) fabrics made from yarn, strip or the like;',
        '',
        '6. Next note.',
      ].join("\n")

      result = formatter.call(input)

      expect(result).to include('    a) textile fabrics impregnated')
      expect(result).to include('    - weighing not more than 1 500 g/m2, or')
      expect(result).to include('    - weighing more than 1 500 g/m2')
      expect(result).to include('    b) fabrics made from yarn, strip or the like;')
      expect(result).to include('6. Next note.')
      expect(result).not_to include('—')
    end

    # ── Rule: (A)/(B)/(C) uppercase sub-markers in chapter notes with nested letter-lists ─
    # EU XHTML nests (A)/(B)/(C) sub-markers at 4 spaces inside a numbered note, then places
    # a)/b)/c) letter-list items 8 spaces deep (one extra XHTML table depth). The
    # letter-list items must be pulled back to 4 spaces (same level as the uppercase marker),
    # not left at 8 spaces which would make them appear as a deeper sub-list.
    # First confirmed: Chapter 84, Note 2.

    # ── Rule: govspeak table rows below list_indent raised to list_indent ──────────
    # When a letter-list item is at 4 spaces, continuation content (including table rows)
    # must also be at 4 spaces. TableFormatter emits rows at 3 spaces (INDENT); those 3-
    # space rows would fall below the list item level. Raise them to list_indent so
    # govspeak keeps the table inside the list item rather than breaking the list.
    # First confirmed: Chapter 74, note 1 — oj-table inside letter-list item (a).

    it 'raises table rows below list_indent to list_indent when inside a letter-list' do
      input = [
        '1. In this chapter, the expressions have the following meanings:',
        '',
        '    a) Refined copper: Metal containing at least 99,85 % by weight of copper.',
        '',
        '   | Element | Limiting content % by weight |',
        '   | --- | --- |',
        '   | Ag Silver | 0,25 |',
        '   | Zn Zinc | 1 |',
        '',
        '    b) Copper alloys: Metallic substances in which copper predominates.',
      ].join("\n")

      result = formatter.call(input)

      expect(result).to include('    | Element | Limiting content % by weight |')
      expect(result).to include('    | --- | --- |')
      expect(result).to include('    | Ag Silver | 0,25 |')
      expect(result).to include('    b) Copper alloys')
      expect(result).not_to include("\n   | Element")
    end

    # ── Rule: roman-numeral / continuation letter-list items deeper than list_indent ──
    # EU XHTML can nest ii)/iii) sub-items one table level deeper than the enclosing
    # a)/b) list when both should be at the same govspeak indent. Pull back to list_indent.
    # Also: plain continuation paragraphs of those deeper items arrive at the same depth
    # and must be pulled back too.
    # First confirmed: Chapter 85, Note 12 — ii) at 8 spaces under a) at 4 spaces.

    it 'pulls a roman-numeral list item deeper than list_indent back to list_indent' do
      input = [
        '12. For the purposes of headings 8541 and 8542:',
        '',
        "    a) (i) 'Semiconductor devices' are devices.",
        '',
        "        ii) 'Light-emitting diodes' are devices based on semiconductor materials.",
        '',
        '        LEDs of heading 8541 do not incorporate power supply elements.',
        '',
        "    b) 'Electronic integrated circuits' are circuits.",
        '',
        '    For the classification of the articles defined in this note, headings 8541 and 8542 shall take precedence.',
      ].join("\n")

      result = formatter.call(input)

      expect(result).to include("    ii) 'Light-emitting diodes'")
      expect(result).to include('    LEDs of heading 8541 do not')
      expect(result).to include("    b) 'Electronic integrated circuits'")
      expect(result).to include('    For the classification of the articles')
      expect(result).not_to include('        ii)')
      expect(result).not_to include('        LEDs')
    end

    # ── Rule: 0-indent letter-list items after list_indent > 0 raised to list_indent ──
    # Sub-items that are sub-sub-items (e.g. b)/c)/d) under a MCO definition item) can
    # arrive at 0 indent from the extractor due to XHTML depth artefacts. When list_indent
    # is already set, they should be raised to list_indent, not left at 0 (which would
    # break govspeak's rendering of the enclosing note and its final paragraph).
    # First confirmed: Chapter 85, Note 12 b)/c)/d) under (3)(a).

    it 'raises 0-indent letter-list continuation items to list_indent when list_indent > 0' do
      input = [
        '12. For the purposes of this note:',
        '',
        "    b) 'Electronic integrated circuits' are:",
        '',
        "    (3) (a) 'Silicon based sensors' consist of microelectronic structures.",
        '',
        "b) 'Silicon based actuators' consist of structures.",
        '',
        "c) 'Silicon based resonators' are components.",
        '',
        '    For the classification of the articles, headings 8541 and 8542 shall take precedence.',
      ].join("\n")

      result = formatter.call(input)

      expect(result).to include("    b) 'Silicon based actuators'")
      expect(result).to include("    c) 'Silicon based resonators'")
      expect(result).to include('    For the classification of the articles')
      expect(result).not_to include("\nb) 'Silicon based actuators'")
      expect(result).not_to include("\nc) 'Silicon based resonators'")
    end

    # ── Rule: A./B. dot-sub-section with nested letter-list and (N) sub-items ──
    # EU OJ XHTML for ch48 note 5 produces a three-level structure:
    #   A./B. at 4 spaces → (a)/(b)/(c) at 8 spaces → (1)/(2) at 12 spaces
    # After normalise_list_marker converts (a)→a), govspeak treats 8+ spaces inside a
    # numbered list item as a code block (scrollable pre box). The formatter must:
    #   • Clamp letter-list items to uppercase_dot_indent + 2 (6 spaces) to stay below
    #     the govspeak code-block threshold.
    #   • Clamp (N) items to the same level (6 spaces) rather than passing through at 12.
    #   • Raise a 0-indent closing paragraph ("Heading 4802 does not...") to
    #     uppercase_dot_indent (4) rather than all the way to list_indent (6).
    # First confirmed: Chapter 48, Note 5 — A./B. sub-sections with (a)/(b)/(1)/(2).
    it 'clamps letter-list and (N) sub-items to uppercase_dot_indent + 2 inside an A./B. dot-sub-section' do
      input = [
        '5. Text satisfying any of the following criteria:',
        '',
        '    A. For paper weighing not more than 150 g/m2:',
        '',
        '        a) containing 10 % or more of fibres, and',
        '',
        '            (1) weighing not more than 80 g/m2; or',
        '',
        '            (2) coloured throughout the mass; or',
        '',
        '        b) containing more than 8 % ash.',
        '',
        '    B. For paper weighing more than 150 g/m2:',
        '',
        '        a) coloured throughout the mass; or',
        '',
        '        b) having a brightness of 60 % or more, and',
        '',
        '            (1) a caliper of 225 micrometres or less; or',
        '',
        '            (2) a caliper of more than 225 micrometres.',
        '',
        '        c) having a brightness of less than 60 %.',
        '',
        '6. Next note.',
      ].join("\n")

      result = formatter.call(input)

      expect(result).to include('      (1) weighing not more than 80 g/m2; or')
      expect(result).to include('      (2) coloured throughout the mass; or')
      expect(result).to include('      (1) a caliper of 225 micrometres or less; or')
      expect(result).to include('      (2) a caliper of more than 225 micrometres.')
      expect(result).to include('      a) containing 10 % or more of fibres, and')
      expect(result).to include('      a) coloured throughout the mass; or')
      expect(result).not_to include("\n        (1) weighing")
      expect(result).not_to include("\n            (1) weighing")
    end

    it 'raises a 0-indent closing paragraph inside A./B. to uppercase_dot_indent (4), not list_indent (6)' do
      input = [
        '5. Text satisfying any of the following criteria:',
        '',
        '    A. For paper weighing not more than 150 g/m2:',
        '',
        '        a) coloured throughout the mass; or',
        '',
        '        b) having brightness of 60 % or more.',
        '',
        '    B. For paper weighing more than 150 g/m2:',
        '',
        '        a) coloured throughout the mass; or',
        '',
        '        b) having a brightness of 60 % or more.',
        '',
        '        c) having a brightness of less than 60 %.',
        '',
        'Heading 4802 does not, however, cover filter paper.',
        '',
        '6. Next note.',
      ].join("\n")

      result = formatter.call(input)

      expect(result).to include('    Heading 4802 does not, however, cover filter paper.')
      expect(result).not_to include('        Heading 4802')
      expect(result).not_to include("\nHeading 4802")
    end

    it 'normalises letter-list items deeper than an uppercase sub-marker to the sub-marker indent' do
      input = [
        '2. In this chapter note 2 introduces some machinery:',
        '',
        '    (A) Heat exchangers of a kind used in various industries:',
        '',
        '        a) industrial cooling systems;',
        '',
        '        b) other heat transfer applications.',
        '',
        '    (B) Machinery for liquefying air or other gases.',
        '',
        '    (C) Centrifuges.',
        '',
        '3. Next note.',
      ].join("\n")

      result = formatter.call(input)

      expect(result).to include('    (A) Heat exchangers')
      expect(result).to include('    a) industrial cooling systems;')
      expect(result).to include('    b) other heat transfer applications.')
      expect(result).to include('    (B) Machinery for liquefying air')
      expect(result).to include('    (C) Centrifuges.')
      expect(result).not_to include('        a)')
      expect(result).not_to include('        b)')
    end

    it 'does not merge when the next non-blank after a comma-terminated list item is another list item' do
      input = [
        '3. This chapter does not cover:',
        '',
        '    (a) item one,',
        '',
        '    (b) item two.',
      ].join("\n")

      expected = [
        '3. This chapter does not cover:',
        '',
        '    a) item one,',
        '',
        '    b) item two.',
      ].join("\n")

      expect(formatter.call(input)).to eq(expected)
    end

    it 'does not alter list items when all siblings share the same indent' do
      input = [
        '3. For the purposes of heading 0405:',
        '',
        '    (a) the term butter means natural butter;',
        '',
        '    (b) the expression dairy spreads means a spreadable emulsion.',
      ].join("\n")

      expected = [
        '3. For the purposes of heading 0405:',
        '',
        '    a) the term butter means natural butter;',
        '',
        '    b) the expression dairy spreads means a spreadable emulsion.',
      ].join("\n")

      expect(formatter.call(input)).to eq(expected)
    end

    # ── Rule: strip spaces before punctuation ────────────────────────────────
    # EU publication leaves a trailing space after heading references before
    # punctuation: "0301 ," "0308 ;" "9508 ."
    # First confirmed: Chapter 01

    it 'removes spaces before commas, semicolons and full stops' do
      input = 'of heading 0301 , 0306 , 0307 or 0308 ;'
      expect(formatter.call(input)).to eq('of heading 0301, 0306, 0307 or 0308;')
    end

    it 'removes a space before a trailing full stop' do
      input = 'animals of heading 9508 .'
      expect(formatter.call(input)).to eq('animals of heading 9508.')
    end

    it 'removes a space before a closing parenthesis' do
      # EU XHTML heading references in parenthetical lists: "heading 0208 or 0210 );"
      # First confirmed: Chapter 03 chapter notes items (b), (c), (d)
      input = 'meat of mammals of heading 0106 (heading 0208 or 0210 );'
      expect(formatter.call(input)).to eq('meat of mammals of heading 0106 (heading 0208 or 0210);')
    end

    it 'removes a space before a colon' do
      input = "the term 'pellets' means products :"
      expect(formatter.call(input)).to eq("the term 'pellets' means products:")
    end

    # ── Rule: collapse internal double spaces ─────────────────────────────────
    # Double spaces arise when two trailing-space artefacts are adjacent.
    # First confirmed: Chapter 01

    it 'collapses double spaces within content while preserving leading indent' do
      input = '    text with  double  spaces inside'
      expect(formatter.call(input)).to eq('    text with double spaces inside')
    end

    # ══════════════════════════════════════════════════════════════════════════
    # Additional Notes section rules
    # (content after "### Additional Notes")
    # ══════════════════════════════════════════════════════════════════════════

    # ── Rule: (a) markers preserved in Additional Notes ───────────────────────
    # Additional Notes use the parenthesised form (a)/(b) — govspeak convention
    # for this section differs from chapter notes. Do NOT convert to a)/b).
    # First confirmed: Chapter 02 Additional Notes

    it 'preserves (a)/(b) markers in Additional Notes (does not strip parens)' do
      input = "### Additional Notes\n\n   (a) first item;\n\n   (b) second item."
      expect(formatter.call(input)).to eq("### Additional Notes\n\n   (a) first item;\n\n   (b) second item.")
    end

    # ── Rule: normalise all-whitespace lines to blank ─────────────────────────
    # EU XHTML deeply nested tables produce lines that are only spaces.
    # First confirmed: Chapter 02 Additional Notes

    it 'treats lines containing only spaces in Additional Notes as blank lines' do
      input = "### Additional Notes\n\nline one\n         \nline two"
      expect(formatter.call(input)).to eq("### Additional Notes\n\nline one\n\nline two")
    end

    # ── Rule: normalise deep indentation ─────────────────────────────────────
    # EU XHTML nests tables 12+ levels deep; depth tracking produces 48+ leading
    # spaces as an artefact. Strip the common base indent to restore readable nesting.
    # First confirmed: Chapter 02 Additional Notes

    it 'strips the common base indent from deeply-indented Additional Notes blocks' do
      # Line 1 at 48 spaces (becomes 0 relative), line 2 at 52 spaces (becomes 4 relative)
      input = "### Additional Notes\n\n#{' ' * 48}top level\n\n#{' ' * 52}nested level"
      expected = "### Additional Notes\n\ntop level\n\n    nested level"
      expect(formatter.call(input)).to eq(expected)
    end

    it 'leaves lines with fewer than 13 leading spaces untouched when deep lines exist' do
      input = "### Additional Notes\n\nnormal line\n\n#{' ' * 48}deep line"
      expect(formatter.call(input)).to eq("### Additional Notes\n\nnormal line\n\ndeep line")
    end

    # ── Rule: merge isolated marker lines with content ────────────────────────
    # EU two-column tables sometimes place the marker ((a), B., —, 1. A.) in
    # one row and the content in the next, producing a label-only line in the
    # extracted output.
    # First confirmed: Chapter 02 Additional Notes

    it 'merges an isolated (a) marker line with the following content line' do
      input = "### Additional Notes\n\n(a)\n\nsome content text"
      expect(formatter.call(input)).to eq("### Additional Notes\n\n   (a) some content text")
    end

    it 'merges an isolated uppercase-letter sub-section label (B.) with content and indents to 3 spaces' do
      input = "### Additional Notes\n\nB.\n\nThe import of the following products is prohibited."
      expect(formatter.call(input)).to eq("### Additional Notes\n\n   B. The import of the following products is prohibited.")
    end

    it 'merges an isolated numbered-plus-letter label (1. A.) with content' do
      input = "### Additional Notes\n\n1. A.\n\nThe following expressions have the meanings hereby assigned to them:"
      expected = "### Additional Notes\n\n1. A. The following expressions have the meanings hereby assigned to them:"
      expect(formatter.call(input)).to eq(expected)
    end

    it 'merges an isolated standalone number (1.) with content and indents it' do
      input = "### Additional Notes\n\n    1.\n\nfats of heading 1502; or"
      expect(formatter.call(input)).to eq("### Additional Notes\n\n      1. fats of heading 1502; or")
    end

    it 'does not merge a line that has content after the marker' do
      input = "### Additional Notes\n\n1. A. The following expressions:\n\n   (a) some text."
      expect(formatter.call(input)).to eq("### Additional Notes\n\n1. A. The following expressions:\n\n   (a) some text.")
    end

    it 'merges a note-number+(a) isolated marker with the following content in Additional Notes' do
      # EU XHTML for Additional Note 6 puts "6." in the label cell and "(a)" as the
      # cell content, then "(a)"'s text in the next row. This is distinct from "1. A."
      # (uppercase) — here the sub-marker is a lowercase parenthetical.
      # First confirmed: Chapter 02 Additional Notes note 6.
      input = [
        '### Additional Notes',
        '',
        '6. (a)',
        '',
        'Uncooked seasoned meats fall in Chapter 16.',
        '',
        '(b) Products falling in heading 0210.',
      ].join("\n")

      expected = [
        '### Additional Notes',
        '',
        '6. (a) Uncooked seasoned meats fall in Chapter 16.',
        '',
        '   (b) Products falling in heading 0210.',
      ].join("\n")

      expect(formatter.call(input)).to eq(expected)
    end

    it 'does not merge an isolated (x) marker when next non-empty line is also an isolated marker' do
      # (h) followed by 1. — both are isolated markers, so (h) stays alone as a heading
      # and 1. is independently merged with its own content.
      input = [
        '### Additional Notes',
        '',
        '(h)',
        '',
        '    1.',
        '',
        '        first sub-item;',
        '',
        '    2.',
        '',
        '        second sub-item.',
      ].join("\n")

      expected = [
        '### Additional Notes',
        '',
        '   (h)',
        '',
        '      1. first sub-item;',
        '',
        '      2. second sub-item.',
      ].join("\n")

      expect(formatter.call(input)).to eq(expected)
    end

    it 'does not merge an isolated (x) marker when next non-empty line is an already-populated indented numbered sub-item' do
      # Simulates extractor output: extractor emits "(h)" alone and "    1. 'crop'..." as
      # a separate block (the sub-table rows were already merged with their labels by the
      # extractor). Without this guard merge_isolated_markers would re-join them into
      # "(h) 1. 'crop'..." — matching the regression seen in Ch02 Additional Notes 1.A.(h).
      # First confirmed: Chapter 02 Additional Notes 1.A.(h).
      input = [
        '### Additional Notes',
        '',
        '(h)',
        '',
        "    1. 'crop' and 'chuck and blade' cuts: the dorsal part of the forequarter;",
        '',
        "    2. 'brisket' cut: the lower part of the forequarter.",
      ].join("\n")

      expected = [
        '### Additional Notes',
        '',
        '   (h)',
        '',
        "      1. 'crop' and 'chuck and blade' cuts: the dorsal part of the forequarter;",
        '',
        "      2. 'brisket' cut: the lower part of the forequarter.",
      ].join("\n")

      expect(formatter.call(input)).to eq(expected)
    end

    # ── Rule: re-anchor (a)/(b) indentation to 3 spaces ──────────────────────
    # After deep-indentation stripping, (a)/(b) markers may still have excess
    # relative indent. Govspeak convention places them at 3 spaces so they sit
    # visually under the sub-note letter (A., B., …) above them.
    # First confirmed: Chapter 02 Additional Notes

    it 'normalises (a)/(b) indentation to 3 spaces in Additional Notes' do
      input = "### Additional Notes\n\n            (a) some definition text;"
      expect(formatter.call(input)).to eq("### Additional Notes\n\n   (a) some definition text;")
    end

    # ── Rule: two-digit note uses 4-space continuation indent in Additional Notes ─
    # Govspeak requires sub-item lines to be indented to the content-start column of
    # the enclosing ordered-list item. For "12. text" that is 4 spaces (not 3), so
    # (a)/(b) items and closing paragraphs inside a two-digit additional note must be
    # at 4 spaces — otherwise govspeak starts a new <ol> for the next note.
    # First confirmed: Chapter 22, Additional Note 12 → Note 13 numbering reset.

    it 'uses 4 spaces for (a)/(b) sub-items inside a two-digit Additional Note' do
      input = [
        '### Additional Notes',
        '',
        '12. Subheading 2207 20 covers mixtures denatured with one or more of the following:',
        '',
        '   (a) automotive petrol;',
        '',
        '   (b) tert-butyl ethyl ether;',
        '',
        '   (c) methyl tert-butylether.',
        '',
        '   The denaturants referred to in (b) and (c) must be used in combination.',
        '',
        '13. For the purposes of subheadings 2202 99 11.',
      ].join("\n")

      result = formatter.call(input)

      expect(result).to include('    (a) automotive petrol;')
      expect(result).to include('    (b) tert-butyl ethyl ether;')
      expect(result).to include('    (c) methyl tert-butylether.')
      expect(result).to include('    The denaturants referred to')
      expect(result).to include('13. For the purposes of subheadings')
      expect(result).not_to include("\n   (a) automotive")
    end

    it 'still uses 3 spaces for (a)/(b) sub-items inside a single-digit Additional Note' do
      input = [
        '### Additional Notes',
        '',
        '9. Note nine with sub-items:',
        '',
        '   (a) first item;',
        '',
        '   (b) second item.',
        '',
        '10. Next note.',
      ].join("\n")

      result = formatter.call(input)

      expect(result).to include('   (a) first item;')
      expect(result).to include('   (b) second item.')
      expect(result).to include('10. Next note.')
    end

    it 'normalises indented numeric sub-items to 6 spaces in Additional Notes' do
      input = "### Additional Notes\n\n    1. fats of heading 1502; or"
      expect(formatter.call(input)).to eq("### Additional Notes\n\n      1. fats of heading 1502; or")
    end

    # ── Rule: collapse consecutive blank lines ─────────────────────────────────
    # Deep-indentation normalisation can leave multiple consecutive blank lines.
    # First confirmed: Chapter 02 Additional Notes

    it 'collapses multiple consecutive blank lines into one' do
      input = "### Additional Notes\n\nline one\n\n\n\nline two"
      expect(formatter.call(input)).to eq("### Additional Notes\n\nline one\n\nline two")
    end

    # ── Rule: em-dash bullet conversion ──────────────────────────────────────
    # EU source uses — (em-dash) as a list bullet in Additional Notes.
    # Govspeak expects markdown dash: "- "
    # First confirmed: Chapter 02 Additional Notes

    it 'converts an em-dash bullet marker to a markdown dash in Additional Notes' do
      input = "### Additional Notes\n\n— prohibition of imports"
      expect(formatter.call(input)).to eq("### Additional Notes\n\n- prohibition of imports")
    end

    it 'merges an isolated em-dash line with content then converts to dash' do
      input = "### Additional Notes\n\n—\n\nprohibition of imports"
      expect(formatter.call(input)).to eq("### Additional Notes\n\n- prohibition of imports")
    end

    # ── Rule: normalise indented bullet indentation to 6 spaces ──────────────
    # Bullet points that sit inside an (a)/(b) item in Additional Notes are
    # over-indented from XHTML nesting. Govspeak expects them at 6 spaces —
    # one level (3 spaces) deeper than the (a)/(b) marker at 3 spaces.
    # First confirmed: Chapter 02 Additional Notes item (c).

    it 'normalises indented bullet points to 6 spaces in Additional Notes' do
      input = "### Additional Notes\n\n   (c) portions composed of either:\n\n            - forequarters; and\n\n            - hindquarters."
      expected = "### Additional Notes\n\n   (c) portions composed of either:\n\n      - forequarters; and\n\n      - hindquarters."
      expect(formatter.call(input)).to eq(expected)
    end

    it 'converts an indented em-dash bullet to a markdown dash at 6 spaces' do
      input = "### Additional Notes\n\n   (c) portions composed of either:\n\n            — forequarters; and"
      expected = "### Additional Notes\n\n   (c) portions composed of either:\n\n      - forequarters; and"
      expect(formatter.call(input)).to eq(expected)
    end

    it 'does not alter top-level bullet points that have no indentation' do
      input = "### Additional Notes\n\n- top level bullet"
      expect(formatter.call(input)).to eq("### Additional Notes\n\n- top level bullet")
    end

    # ── Rule: uppercase sub-section labels (B., C.) → 3-space indent ─────────
    # B./C./D. are siblings of A. within the same numbered note (1. A./B./C.).
    # Govspeak needs them at 3 spaces so it knows they're still inside the "1."
    # item — without this indent, "2. A." is miscounted as "1. A.".
    # First confirmed: Chapter 02 Additional Notes (note 1 sections B and C).

    it 'normalises uppercase sub-section labels (B., C.) to 3-space indent' do
      # B. and C. appear as isolated markers then get merged with their content
      input = [
        '### Additional Notes',
        '',
        'B.',
        '',
        'Products covered by this chapter.',
        '',
        'C.',
        '',
        'In determining the number of ribs.',
        '',
        '2. A. The following expressions apply:',
      ].join("\n")

      expected = [
        '### Additional Notes',
        '',
        '   B. Products covered by this chapter.',
        '',
        '   C. In determining the number of ribs.',
        '',
        '2. A. The following expressions apply:',
      ].join("\n")

      expect(formatter.call(input)).to eq(expected)
    end

    it 'normalises a standalone uppercase sub-section label to 3 spaces when it has no content' do
      input = "### Additional Notes\n\nB."
      expect(formatter.call(input)).to eq("### Additional Notes\n\n   B.")
    end

    it 'does not re-indent a numbered note line that starts with a digit (2. A. …)' do
      input = "### Additional Notes\n\n2. A. The following expressions apply:"
      expect(formatter.call(input)).to eq("### Additional Notes\n\n2. A. The following expressions apply:")
    end

    # ── Rule: indent continuation paragraphs inside sub-sections to 3 spaces ─
    # EU XHTML two-column tables can emit each sentence as a separate row with
    # an empty label cell. These rows come through at 0-1 space indent but are
    # semantically inside the preceding B./C./(a) sub-section.
    # The formatter tracks context (inside_sub_section flag) to re-indent them
    # to 3 spaces, preventing govspeak from miscounting numbered notes.
    # First confirmed: Chapter 02 Additional Notes, sections C and D.
    # Without this rule "3. A." renders as "1. A." because C.'s continuation
    # paragraphs fall outside the indent scope of note 1.

    it 'indents continuation paragraphs within uppercase sub-sections to 3 spaces' do
      # C. and D. have secondary sentences in separate extractor rows (0-1 space indent).
      # The cheeks/snouts paragraph and "These subheadings" line are continuation text.
      # "3. A." at 0 indent must reset context and stay at 0.
      input = [
        '### Additional Notes',
        '',
        'C. Main sentence, includes parts thereof.',
        ' The head is separated from the carcase as follows:',
        '',
        '      - by a straight cut; or',
        '',
        '      - by a parallel cut.',
        '',
        ' The cheeks and snouts are considered parts of heads.',
        '',
        'D. For the purposes of subheading 0209 10, fat has the following meaning.',
        ' These subheadings also include fat without rind.',
        '',
        '3. A. For the purposes of heading 0204, the following expressions apply:',
      ].join("\n")

      expected = [
        '### Additional Notes',
        '',
        '   C. Main sentence, includes parts thereof.',
        '   The head is separated from the carcase as follows:',
        '',
        '      - by a straight cut; or',
        '',
        '      - by a parallel cut.',
        '',
        '   The cheeks and snouts are considered parts of heads.',
        '',
        '   D. For the purposes of subheading 0209 10, fat has the following meaning.',
        '   These subheadings also include fat without rind.',
        '',
        '3. A. For the purposes of heading 0204, the following expressions apply:',
      ].join("\n")

      expect(formatter.call(input)).to eq(expected)
    end

    # ── Rule: cap over-indented continuation text at 6 spaces ────────────────
    # The EU XHTML sometimes nests a continuation paragraph one level deeper
    # than the bullet list it follows (12 spaces vs 6 for bullets). Govspeak
    # needs it at the same 6-space level as the bullets.
    # First confirmed: Chapter 02 Additional Notes 1.A.(c) — "The forequarters
    # and hindquarters constituting 'compensated quarters' must be presented..."
    # arriving at 12 spaces instead of 6.

    it 'normalises over-indented continuation text after bullets to 6 spaces' do
      input = [
        '### Additional Notes',
        '',
        "(c) 'compensated quarters': portions composed of either:",
        '',
        '      - forequarters at the tenth rib; or',
        '',
        '      - forequarters at the fifth rib.',
        '',
        '            The forequarters and hindquarters must be presented at the same time.',
      ].join("\n")

      expected = [
        '### Additional Notes',
        '',
        "   (c) 'compensated quarters': portions composed of either:",
        '',
        '      - forequarters at the tenth rib; or',
        '',
        '      - forequarters at the fifth rib.',
        '',
        '      The forequarters and hindquarters must be presented at the same time.',
      ].join("\n")

      expect(formatter.call(input)).to eq(expected)
    end

    # ── Rule: raise continuation content under standalone dash-bullets to 9 spaces ─
    # EU XHTML chemical composition lists (e.g. ch72 'Tool steel') use — sub-bullets
    # at 6 spaces with 'and'/'or' connectors at 3 spaces and composition values at
    # 0 spaces. These are multi-line continuations of the bullet item above them.
    # When not inside an (a)/(b) sub-section, they must be raised to 9 spaces so
    # govspeak renders them as continuation of the 6-space bullet, not loose paragraphs.
    # The guard !inside_sub_section preserves the existing behaviour for bullets that
    # appear inside (a)/(b) sub-sections (e.g. ch02), where continuation text is
    # already correctly handled by inside_sub_section → 3 spaces.
    # First confirmed: Chapter 72 Additional Notes, 'Tool steel' composition list.

    it 'raises continuation content under standalone dash-bullets to 9 spaces' do
      input = [
        '### Additional Notes',
        '',
        '1. Tool steel definitions:',
        '',
        '      - less than 0,6 % of carbon',
        '',
        '   and',
        '',
        '0,7 % or more of silicon, or',
        '',
        '   or',
        '',
        '4 % or more of tungsten,',
        '',
        '      - 0,8 % or more of carbon',
        '',
        '   and',
        '',
        '0,05 % or more of vanadium.',
      ].join("\n")

      result = formatter.call(input)

      expect(result).to include('      - less than 0,6 % of carbon')
      expect(result).to include('         and')
      expect(result).to include('         0,7 % or more of silicon, or')
      expect(result).to include('         or')
      expect(result).to include('         4 % or more of tungsten,')
      expect(result).to include('      - 0,8 % or more of carbon')
      expect(result).to include('         0,05 % or more of vanadium.')
    end

    it 'does not raise continuation content after dash-bullets that are inside a sub-section' do
      input = [
        '### Additional Notes',
        '',
        'C. Heading text.',
        ' continuation of C.',
        '',
        '      - bullet one',
        '',
        ' continuation after bullet',
        '',
        '3. A. Next note.',
      ].join("\n")

      result = formatter.call(input)

      expect(result).to include('   continuation after bullet')
      expect(result).not_to include('         continuation after bullet')
    end

    it 'indents continuation paragraphs inside (a)/(b) sub-items to 3 spaces' do
      # An (a) item with a second sentence in a separate extractor row at 1 space indent.
      input = [
        '### Additional Notes',
        '',
        '(a) first sentence of item a.',
        ' second sentence still inside item a.',
        '',
        '(b) item b text.',
      ].join("\n")

      expected = [
        '### Additional Notes',
        '',
        '   (a) first sentence of item a.',
        '   second sentence still inside item a.',
        '',
        '   (b) item b text.',
      ].join("\n")

      expect(formatter.call(input)).to eq(expected)
    end

    # ── Rule: indent continuation paragraphs under numbered notes to 3 spaces ──
    # EU XHTML places each numbered note and its continuation paragraphs as
    # separate rows. After extraction, continuation paragraphs arrive at 0 indent.
    # Govspeak requires them at 3 spaces so they sit inside the numbered note item.
    # Without this indent, subsequent numbered notes are miscounted.
    # First confirmed: Chapter 03 Additional Notes (notes 1 and 2).

    it 'indents continuation paragraphs under a numbered note to 3 spaces in Additional Notes' do
      input = [
        '### Additional Notes',
        '',
        '1. For the purposes of subheadings 0305 32 11, cod fillets are considered to be salted fish.',
        '',
        'However, frozen cod fillets which have a total salt content of less than 12 % are classified elsewhere.',
        '',
        "2. For the purposes of the subheadings referred to, the term 'fillets' includes 'loins'.",
        '',
        'The classification of such products as fillets is unaffected by cutting them into pieces.',
        '',
        'The provisions of the first two paragraphs apply to the following fish:',
        '',
        '   (a) tuna, of the genus Thunnus;',
        '',
        '   (b) swordfish (Xiphias gladius);',
      ].join("\n")

      expected = [
        '### Additional Notes',
        '',
        '1. For the purposes of subheadings 0305 32 11, cod fillets are considered to be salted fish.',
        '',
        '   However, frozen cod fillets which have a total salt content of less than 12 % are classified elsewhere.',
        '',
        "2. For the purposes of the subheadings referred to, the term 'fillets' includes 'loins'.",
        '',
        '   The classification of such products as fillets is unaffected by cutting them into pieces.',
        '',
        '   The provisions of the first two paragraphs apply to the following fish:',
        '',
        '   (a) tuna, of the genus Thunnus;',
        '',
        '   (b) swordfish (Xiphias gladius);',
      ].join("\n")

      expect(formatter.call(input)).to eq(expected)
    end

    # ══════════════════════════════════════════════════════════════════════════
    # Integration tests
    # ══════════════════════════════════════════════════════════════════════════

    it 'correctly formats Chapter 01 chapter note' do
      input = <<~TEXT
        1. This chapter covers all live animals, except:

            (a) fish and crustaceans, molluscs and other aquatic invertebrates, of heading 0301 , 0306 , 0307  or 0308 ;

            (b) cultures of micro-organisms and other products of heading 3002 ; and

            (c) animals of heading 9508 .
      TEXT

      expected = <<~TEXT
        1. This chapter covers all live animals, except:

            a) fish and crustaceans, molluscs and other aquatic invertebrates, of heading 0301, 0306, 0307 or 0308;

            b) cultures of micro-organisms and other products of heading 3002; and

            c) animals of heading 9508.
      TEXT

      expect(formatter.call(input.chomp)).to eq(expected.chomp)
    end

    it 'correctly formats a Chapter 02 Additional Notes block' do
      # Simulates extractor output: "1. A." in one row, content at deep indent;
      # (a)/(b) markers isolated; B. sub-section isolated; (a)/(b) keep parens.
      base = ' ' * 48
      input = [
        '1. A.',
        '',
        "#{base}The following expressions have the meanings hereby assigned to them:",
        '',
        "#{base}    (a)",
        '',
        "#{base}        'carcases of bovine animals' means the whole carcases;",
        '',
        "#{base}    (b)",
        '',
        "#{base}        'half-carcases' means the product obtained by splitting;",
      ].join("\n")

      # Wrap in Additional Notes section as the extractor would produce
      full_input = "### Additional Notes\n\n#{input}"

      expected = [
        '### Additional Notes',
        '',
        '1. A. The following expressions have the meanings hereby assigned to them:',
        '',
        "   (a) 'carcases of bovine animals' means the whole carcases;",
        '',
        "   (b) 'half-carcases' means the product obtained by splitting;",
      ].join("\n")

      expect(formatter.call(full_input)).to eq(expected)
    end

    # ── Rule: uppercase (A)/(B) sub-markers in deeply-indented chapter notes ───
    # EU XHTML can use uppercase (A)/(B) as sub-markers inside a numbered note, with
    # both the marker and its content at ~48 spaces of indentation from the table depth.
    # normalise_deep_indentation (now also in format_main_part) strips the base indent;
    # merge_trailing_list_markers (extended to [a-zA-Z]+) merges the isolated marker with
    # its content; indent_note_continuations re-indents sibling (B)/(C) etc. to 3
    # spaces, matching the chapter-note govspeak convention.
    # First confirmed: Chapter 10 note 1.

    it 'merges uppercase (A)/(B) sub-markers from deeply-indented chapter notes and indents siblings to 3 spaces' do
      indent     = ' ' * 48
      whitespace = ' ' * 45
      input = [
        '1. (A)',
        whitespace,
        "#{indent}The products specified in the headings of this chapter.",
        whitespace,
        "#{indent}(B)",
        whitespace,
        "#{indent}The Chapter does not cover grains.",
        '',
        '2. Heading 1005 does not cover sweetcorn.',
      ].join("\n")

      result = formatter.call(input)

      expect(result).to include('1. (A) The products specified in the headings of this chapter.')
      expect(result).to include('   (B) The Chapter does not cover grains.')
      expect(result).to include('2. Heading 1005 does not cover sweetcorn.')
    end

    it 'does not indent a numbered note that follows a note with uppercase (A)/(B) sub-markers' do
      indent     = ' ' * 48
      whitespace = ' ' * 45
      input = [
        '1. (A)',
        whitespace,
        "#{indent}First note content.",
        '',
        '2. Second note has no uppercase sub-markers.',
      ].join("\n")

      result = formatter.call(input)

      expect(result).to include('1. (A) First note content.')
      expect(result).to include('2. Second note has no uppercase sub-markers.')
      expect(result).not_to match(/\A {3,}2\./)
    end

    # ── Rule: normalise sub-items inside N. (A) notes to 3-space indent ─────────
    # When a note opens with "N. (A) text", the EU XHTML nests the sub-tables one
    # level deeper than the enclosing note table. (a)/(b) items arrive at 8 spaces
    # (depth=2) and (B)/(C) siblings at 4 spaces (depth=1). Govspeak needs them all
    # at 3 spaces — the standard continuation indent for a numbered list item.
    # normalise_uppercase_sub_note_indentation re-indents lines at ≥ 4 spaces to 3.
    # indent_note_continuations then correctly raises "Otherwise…" paragraphs
    # (arriving at 0 from the extractor) to list_indent=3.
    # First confirmed: Chapter 11 note 2 (cereal milling classification).

    it 'normalises sub-items and continuation paragraphs under N. (A) notes to 3-space indent' do
      # Extractor output: (A)+(B) at depth=1 (4 spaces), (a)/(b) at depth=2 (8 spaces),
      # "Otherwise…" paragraphs at 0 indent from the extractor.
      input = [
        '2.     (A) Products from the milling of the cereals if they have:',
        '',
        '        (a) a starch content exceeding column 2; and',
        '',
        '        (b) an ash content not exceeding column 3.',
        '',
        'Otherwise, they fall in heading 2302.',
        '',
        '    (B) Products falling in this chapter shall be classified in heading 1101.',
        '',
        'Otherwise, they fall in heading 1103.',
        '',
        '3. This note covers something else.',
      ].join("\n")

      result = formatter.call(input)

      expect(result).to include('2. (A) Products from the milling')
      expect(result).to include('   a) a starch content exceeding column 2; and')
      expect(result).to include('   b) an ash content not exceeding column 3.')
      expect(result).to include('   Otherwise, they fall in heading 2302.')
      expect(result).to include('   (B) Products falling in this chapter')
      expect(result).to include('   Otherwise, they fall in heading 1103.')
      expect(result).to include('3. This note covers something else.')
    end

    it 'normalises (B)/(C) sub-markers at 4 spaces to 3 spaces when under a N. (A) note' do
      # (B)/(C) arrive at 4 spaces from a depth=1 sub-table in the XHTML. The new
      # normalise_uppercase_sub_note_indentation pass re-indents ≥ 4 space items to 3.
      input = [
        '1. (A) First sub-section content.',
        '',
        '    (B) Second sub-section content.',
        '',
        '    (C) Third sub-section content.',
        '',
        '2. Next note.',
      ].join("\n")

      result = formatter.call(input)

      expect(result).to include('1. (A) First sub-section content.')
      expect(result).to include('   (B) Second sub-section content.')
      expect(result).to include('   (C) Third sub-section content.')
      expect(result).to include('2. Next note.')
    end

    it 'applies chapter-note rules to chapter part and additional-note rules to additional part' do
      input = [
        '1. This chapter covers:',
        '',
        '    (a) fish of heading 0301 , 0306 ;',
        '',
        '### Additional Notes',
        '',
        '1. A.',
        '',
        'The following expressions apply:',
        '',
        '(a)',
        '',
        'definition text;',
      ].join("\n")

      expected = [
        '1. This chapter covers:',
        '',
        '    a) fish of heading 0301, 0306;',
        '',
        '### Additional Notes',
        '',
        '1. A. The following expressions apply:',
        '',
        '   (a) definition text;',
      ].join("\n")

      expect(formatter.call(input)).to eq(expected)
    end
  end
end
