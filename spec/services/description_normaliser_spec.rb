RSpec.describe DescriptionNormaliser do
  describe '.call' do
    it 'returns empty string for nil' do
      expect(described_class.call(nil)).to eq('')
    end

    it 'returns empty string for blank string' do
      expect(described_class.call('')).to eq('')
      expect(described_class.call('   ')).to eq('')
    end

    context 'with HTML tags' do
      it 'replaces <br> with space' do
        expect(described_class.call('first<br>second')).to eq('first second')
      end

      it 'replaces <br/> with space' do
        expect(described_class.call('first<br/>second')).to eq('first second')
      end

      it 'replaces <br /> with space' do
        expect(described_class.call('first<br />second')).to eq('first second')
      end

      it 'replaces <p/> with space' do
        expect(described_class.call('first<p/>second')).to eq('first second')
      end

      it 'unwraps <sup> tags' do
        expect(described_class.call('10<sup>2</sup> kg')).to eq('102 kg')
      end

      it 'unwraps <sub> tags' do
        expect(described_class.call('H<sub>2</sub>O')).to eq('H2O')
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

      it 'decodes &deg; to degrees' do
        expect(described_class.call('90&deg;')).to eq('90 degrees')
      end

      it 'decodes &amp; to &' do
        expect(described_class.call('bread &amp; butter')).to eq('bread & butter')
      end

      it 'decodes &nbsp; to space' do
        expect(described_class.call('a&nbsp;b')).to eq('a b')
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

      it 'normalizes non-breaking hyphen' do
        expect(described_class.call("self\u2011text")).to eq('self-text')
      end

      it 'normalizes minus sign' do
        expect(described_class.call("5 \u2212 3")).to eq('5 - 3')
      end

      it 'normalizes non-breaking space' do
        expect(described_class.call("a\u00A0b")).to eq('a b')
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

      it 'normalizes degree celsius' do
        expect(described_class.call("100 \u2103")).to eq('100 degrees C')
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

      it 'preserves superscript digits' do
        expect(described_class.call("10\u00B2")).to eq("10\u00B2")
      end
    end

    context 'with control characters' do
      it 'strips null bytes' do
        expect(described_class.call("test\x00value")).to eq('testvalue')
      end

      it 'strips C0 control characters' do
        expect(described_class.call("test\x01\x02\x03value")).to eq('testvalue')
      end

      it 'preserves tabs and newlines before whitespace collapse' do
        # tabs and newlines are collapsed to single space
        expect(described_class.call("first\tsecond")).to eq('first second')
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
        expected = 'Milk & cream, not concentrated, of a fat content <= 1%2'

        expect(described_class.call(input)).to eq(expected)
      end

      it 'normalizes a description with <p/> paragraph breaks' do
        input = 'First paragraph<p/>Second paragraph<p/>Third'
        expected = 'First paragraph Second paragraph Third'

        expect(described_class.call(input)).to eq(expected)
      end

      it 'normalizes a description with Unicode operators' do
        input = "Weight \u2265 5 kg and \u2264 10 kg, 2 \u00D7 3 cm"
        expected = 'Weight >= 5 kg and <= 10 kg, 2 x 3 cm'

        expect(described_class.call(input)).to eq(expected)
      end
    end
  end
end
