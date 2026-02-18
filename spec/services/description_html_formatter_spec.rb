RSpec.describe DescriptionHtmlFormatter do
  describe '.call' do
    it 'returns empty string for nil' do
      expect(described_class.call(nil)).to eq('')
    end

    it 'returns empty string for blank string' do
      expect(described_class.call('')).to eq('')
      expect(described_class.call('   ')).to eq('')
    end

    context 'with HTML tags' do
      it 'preserves <br> tags' do
        expect(described_class.call('first<br>second')).to eq('first<br>second')
      end

      it 'preserves <br/> tags' do
        expect(described_class.call('first<br/>second')).to eq('first<br/>second')
      end

      it 'preserves <br /> tags' do
        expect(described_class.call('first<br />second')).to eq('first<br />second')
      end

      it 'preserves <sup> tags' do
        expect(described_class.call('10<sup>2</sup> kg')).to eq('10<sup>2</sup> kg')
      end

      it 'preserves <sub> tags' do
        expect(described_class.call('H<sub>2</sub>O')).to eq('H<sub>2</sub>O')
      end

      it 'converts <p/> to <br>' do
        expect(described_class.call('first<p/>second')).to eq('first<br>second')
      end

      it 'strips other HTML tags' do
        expect(described_class.call('<ul><li>item</li></ul>')).to eq('item')
      end
    end

    context 'with HTML entities' do
      it 'decodes &ge; to >=' do
        expect(described_class.call('&ge; 5')).to eq('>= 5')
      end

      it 'decodes &le; to <=' do
        expect(described_class.call('&le; 10')).to eq('<= 10')
      end

      it 'decodes &times; to x' do
        expect(described_class.call('2 &times; 3')).to eq('2 x 3')
      end

      it 'decodes &deg; to degree sign' do
        expect(described_class.call('90&deg;')).to eq("90\u00B0")
      end

      it 'decodes &amp; to &' do
        expect(described_class.call('bread &amp; butter')).to eq('bread & butter')
      end

      it 'decodes &nbsp; to non-breaking space' do
        expect(described_class.call('a&nbsp;b')).to eq("a\u00A0b")
      end

      it 'decodes numeric character references' do
        expect(described_class.call('&#39;quoted&#39;')).to eq("'quoted'")
      end

      it 'decodes hex character references' do
        expect(described_class.call('&#x27;quoted&#x27;')).to eq("'quoted'")
      end
    end

    context 'with Unicode characters' do
      it 'normalizes smart single quotes' do
        expect(described_class.call("\u2018hello\u2019")).to eq("'hello'")
      end

      it 'normalizes smart double quotes' do
        expect(described_class.call("\u201Chello\u201D")).to eq('"hello"')
      end

      it 'normalizes en-dash' do
        expect(described_class.call("1\u20132")).to eq('1-2')
      end

      it 'normalizes em-dash' do
        expect(described_class.call("1\u20142")).to eq('1-2')
      end

      it 'normalizes non-breaking hyphen' do
        expect(described_class.call("self\u2011text")).to eq('self-text')
      end

      it 'normalizes minus sign' do
        expect(described_class.call("5 \u2212 3")).to eq('5 - 3')
      end

      it 'preserves non-breaking space' do
        expect(described_class.call("a\u00A0b")).to eq("a\u00A0b")
      end

      it 'strips zero-width space' do
        expect(described_class.call("test\u200Bvalue")).to eq('testvalue')
      end

      it 'strips soft hyphen' do
        expect(described_class.call("test\u00ADvalue")).to eq('testvalue')
      end

      it 'normalizes >= operator' do
        expect(described_class.call("\u2265 5")).to eq('>= 5')
      end

      it 'normalizes <= operator' do
        expect(described_class.call("\u2264 10")).to eq('<= 10')
      end

      it 'normalizes multiplication sign' do
        expect(described_class.call("2 \u00D7 3")).to eq('2 x 3')
      end

      it 'decomposes degree celsius to degree sign + C' do
        expect(described_class.call("100 \u2103")).to eq("100 \u00B0C")
      end
    end

    context 'with Unicode superscripts' do
      it 'converts superscript 2 to <sup> tag' do
        expect(described_class.call("10\u00B2")).to eq('10<sup>2</sup>')
      end

      it 'converts superscript 3 to <sup> tag' do
        expect(described_class.call("m\u00B3")).to eq('m<sup>3</sup>')
      end

      it 'converts superscript 0 to <sup> tag' do
        expect(described_class.call("x\u2070")).to eq('x<sup>0</sup>')
      end

      it 'converts consecutive superscripts' do
        expect(described_class.call("10\u00B2\u00B3")).to eq('10<sup>2</sup><sup>3</sup>')
      end
    end

    context 'with Unicode subscripts' do
      it 'converts subscript 2 to <sub> tag' do
        expect(described_class.call("H\u2082O")).to eq('H<sub>2</sub>O')
      end

      it 'converts subscript 3 to <sub> tag' do
        expect(described_class.call("C\u2083")).to eq('C<sub>3</sub>')
      end

      it 'converts subscript 0 to <sub> tag' do
        expect(described_class.call("x\u2080")).to eq('x<sub>0</sub>')
      end
    end

    context 'with valid Unicode that should be preserved' do
      it 'preserves accented letters' do
        expect(described_class.call("cafe\u0301")).to include("cafe\u0301")
      end

      it 'preserves degree sign' do
        expect(described_class.call("90\u00B0C")).to eq("90\u00B0C")
      end

      it 'preserves pound sign' do
        expect(described_class.call("\u00A3100")).to eq("\u00A3100")
      end

      it 'preserves micro sign' do
        expect(described_class.call("5 \u00B5m")).to eq("5 \u00B5m")
      end
    end

    context 'with control characters' do
      it 'strips null bytes' do
        expect(described_class.call("test\x00value")).to eq('testvalue')
      end

      it 'strips C0 control characters' do
        expect(described_class.call("test\x01\x02\x03value")).to eq('testvalue')
      end

      it 'collapses tab to space' do
        expect(described_class.call("first\tsecond")).to eq('first second')
      end

      it 'converts newline to <br>' do
        expect(described_class.call("first\nsecond")).to eq('first<br>second')
      end
    end

    context 'with whitespace' do
      it 'collapses multiple spaces' do
        expect(described_class.call('a   b    c')).to eq('a b c')
      end

      it 'strips leading and trailing whitespace' do
        expect(described_class.call('  hello  ')).to eq('hello')
      end
    end

    context 'with realistic tariff descriptions' do
      it 'normalizes a description with HTML and entities' do
        input = 'Milk &amp; cream, not concentrated,<br>of a fat content &le; 1%<sup>2</sup>'
        expected = 'Milk & cream, not concentrated,<br>of a fat content <= 1%<sup>2</sup>'

        expect(described_class.call(input)).to eq(expected)
      end

      it 'normalizes a description with <p/> paragraph breaks' do
        input = 'First paragraph<p/>Second paragraph<p/>Third'
        expected = 'First paragraph<br>Second paragraph<br>Third'

        expect(described_class.call(input)).to eq(expected)
      end

      it 'normalizes a description with Unicode operators' do
        input = "Weight \u2265 5 kg and \u2264 10 kg, 2 \u00D7 3 cm"
        expected = 'Weight >= 5 kg and <= 10 kg, 2 x 3 cm'

        expect(described_class.call(input)).to eq(expected)
      end

      it 'normalizes Unicode superscripts alongside HTML sup tags' do
        input = "10\u00B2 and 10<sup>3</sup>"
        expected = '10<sup>2</sup> and 10<sup>3</sup>'

        expect(described_class.call(input)).to eq(expected)
      end
    end

    context 'with TARIC markup' do
      it 'converts $X superscript markup to <sup> tags' do
        expect(described_class.call('10$-<sup>6</sup>')).to eq('10<sup>-</sup><sup>6</sup>')
      end

      it 'converts @X subscript markup to <sub> tags' do
        expect(described_class.call('H@2O')).to eq('H<sub>2</sub>O')
      end

      it 'converts !1! to <br>' do
        expect(described_class.call('first!1!second')).to eq('first<br>second')
      end

      it 'converts || to <br>' do
        expect(described_class.call('heading||5303')).to eq('heading<br>5303')
      end

      it 'converts single pipe to non-breaking space' do
        expect(described_class.call('80|kg')).to eq("80\u00A0kg")
      end

      it 'converts !X! to multiplication' do
        expect(described_class.call('nitrogen|!x!|6,38')).to eq("nitrogen\u00A0x\u00A06,38")
      end

      it 'converts !o! to degree sign' do
        expect(described_class.call('20 !o!C')).to eq("20 \u00B0C")
      end

      it 'converts !>=! to >=' do
        expect(described_class.call('!>=! 5')).to eq('>= 5')
      end

      it 'converts !<=! to <=' do
        expect(described_class.call('!<=! 10')).to eq('<= 10')
      end

      it 'handles a realistic XI description with mixed TARIC markup' do
        input = 'Of a density exceeding|1,33|g/cm$3|at 20 !o!C'
        expected = "Of a density exceeding\u00A01,33\u00A0g/cm<sup>3</sup>\u00A0at 20 \u00B0C"

        expect(described_class.call(input)).to eq(expected)
      end
    end
  end
end
