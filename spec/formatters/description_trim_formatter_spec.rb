RSpec.describe DescriptionTrimFormatter do
  describe '.format' do
    it 'replaces | with empty space' do
      expect(
        described_class.format(description: '|'),
      ).to eq ' '
    end

    it 'strips !1!' do
      expect(
        described_class.format(description: '!1!'),
      ).to eq ''
    end

    it 'strips !X!' do
      expect(
        described_class.format(description: '!X!'),
      ).to eq ''
    end

    it 'strips !x!' do
      expect(
        described_class.format(description: '!x!'),
      ).to eq ''
    end

    it 'strips !o!' do
      expect(
        described_class.format(description: '!o!'),
      ).to eq ''
    end

    it 'strips !O!' do
      expect(
        described_class.format(description: '!O!'),
      ).to eq ''
    end

    it 'strips !>=!' do
      expect(
        described_class.format(description: '!>=!'),
      ).to eq ''
    end

    it 'strips !<=!' do
      expect(
        described_class.format(description: '!<=!'),
      ).to eq ''
    end

    it 'replaces  @<anycharacter> with <anycharacter>' do
      expect(
        described_class.format(description: '@1'),
      ).to eq '1'
    end

    it 'replaces $<anycharacter> with <anycharacter>' do
      expect(
        described_class.format(description: '$1'),
      ).to eq '1'
    end

    it 'return empty string for empty description' do
      expect(
        described_class.format(description: nil),
      ).to eq ''

      expect(
        described_class.format(description: ''),
      ).to eq ''

      expect(
        described_class.format(description: '    '),
      ).to eq ''
    end
  end
end
