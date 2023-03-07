RSpec.describe DescriptionFormatter do
  describe '.format' do
    it 'correctly escapes lists' do
      description = '-| bread -| butter'

      expect(
        described_class.format(description:),
      ).to eq '<br/>- bread <br/>- butter'
    end

    it 'corrects inconsistent newlines in lists' do
      description = "\n-| bread -| butter"

      expect(
        described_class.format(description:),
      ).to eq '<br/>- bread <br/>- butter'
    end

    it 'replaces & with ampersands' do
      description = 'bread & butter'

      expect(
        described_class.format(description:),
      ).to eq 'bread &amp; butter'
    end

    it 'does not replace & followed with # (html entity)' do
      description = '&#39;A&#39; with an &#39;X&#39;'

      expect(
        described_class.format(description:),
      ).to eq description
    end

    it 'does not replace & followed by nbsp (non breaking space entity)' do
      description = 'a&nbsp;paragraph'

      expect(
        described_class.format(description:),
      ).to eq description
    end

    it 'replaces | with non breaking space html entity' do
      expect(
        described_class.format(description: ' | '),
      ).to eq ' &nbsp; '
    end

    it 'replaces !1! with breaking space tags' do
      expect(
        described_class.format(description: ' !1! '),
      ).to eq ' <br /> '
    end

    it 'removes special space character from 1nbsp%' do
      expect(
        described_class.format(description: ' 85 % '),
      ).to eq ' 85% '
    end

    it 'replaces !X! with times html entity' do
      expect(
        described_class.format(description: ' !X! '),
      ).to eq ' &times; '
    end

    it 'replaces !x! with times html entity' do
      expect(
        described_class.format(description: ' !x! '),
      ).to eq ' &times; '
    end

    it 'replaces !o! with deg html entity' do
      expect(
        described_class.format(description: ' !o! '),
      ).to eq ' &deg; '
    end

    it 'replaces !O! with deg html entity' do
      expect(
        described_class.format(description: ' !O! '),
      ).to eq ' &deg; '
    end

    it 'replaces !>=! with greater or equals html entity' do
      expect(
        described_class.format(description: ' !>=! '),
      ).to eq ' &ge; '
    end

    it 'replaces !<=! with less or equal html entity' do
      expect(
        described_class.format(description: ' !<=! '),
      ).to eq ' &le; '
    end

    it 'replaces and wraps @<anycharacter> with html sub tag' do
      expect(
        described_class.format(description: ' @1 '),
      ).to eq ' <sub>1</sub> '
    end

    it 'replaces and wraps $<anycharacter> with html sup tag' do
      expect(
        described_class.format(description: ' $1 '),
      ).to eq ' <sup>1</sup> '
    end

    it 'replaces @<anycharacter> with html sub tag' do
      expect(
        described_class.format(description: ' @2 '),
      ).to eq ' <sub>2</sub> '
    end

    it 'returns empty string for nil description' do
      expect(
        described_class.format(description: nil),
      ).to eq ''
    end

    it 'returns empty string for empty description' do
      expect(
        described_class.format(description: ''),
      ).to eq ''
    end

    it 'returns empty string for nothing but spaces' do
      expect(
        described_class.format(description: '    '),
      ).to eq ''
    end

    it 'replaces , with .' do
      expect(
        described_class.format(description: ' 11,11% '),
      ).to eq ' 11.11% '
    end

    it 'replaces izing with ising' do
      expect(
        described_class.format(description: ' vaporizing '),
      ).to eq ' vaporising '
    end

    it 'replaces ization with isation' do
      expect(
        described_class.format(description: ' utilization '),
      ).to eq ' utilisation '
    end

    it 'replaces ized with ised' do
      expect(
        described_class.format(description: ' unpasteurized '),
      ).to eq ' unpasteurised '
    end

    it 'removes sub tag from emails' do
      expect(
        described_class.format(description: ' email<sub>h</sub>se.gov.uk '),
      ).to eq ' email@hse.gov.uk '
    end

    it 'removes br before li' do
      expect(
        described_class.format(description: ' <br><li> '),
      ).to eq ' <li> '
    end

    it 'removes br before ul' do
      expect(
        described_class.format(description: ' <br><br><ul> '),
      ).to eq ' <ul> '
    end

    it 'removes br surrounding ul' do
      expect(
        described_class.format(description: ' <br></ul><br> '),
      ).to eq ' </ul> '
    end

    it 'replaces 3 or more br with 2' do
      expect(
        described_class.format(description: ' <br><br><br> '),
      ).to eq ' <br><br> '
    end

    it 'replaces 4 br with 2' do
      expect(
        described_class.format(description: ' <br><br><br><br> '),
      ).to eq ' <br><br> '
    end

    context 'when xi' do
      before do
        allow(TradeTariffBackend).to receive(:uk?).and_return(false)
      end

      it 'does not replace , with .' do
        expect(
          described_class.format(description: ' 11,11% '),
        ).to eq ' 11,11% '
      end

      it 'does not replace izing with ising' do
        expect(
          described_class.format(description: ' vaporizing '),
        ).to eq ' vaporizing '
      end

      it 'does not replace ization with isation' do
        expect(
          described_class.format(description: ' utilization '),
        ).to eq ' utilization '
      end

      it 'does not replace ized  with ised' do
        expect(
          described_class.format(description: ' unpasteurized '),
        ).to eq ' unpasteurized '
      end
    end
  end
end
