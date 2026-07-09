RSpec.describe TariffKnowledge::NoteFragmentSplitter do
  describe '.call' do
    it 'merges orphaned list markers into the following fragment' do
      fragments = described_class.call("1. Definitions:\n\na.\n\npig iron")

      expect(fragments).to eq(['1. Definitions:', 'a. pig iron'])
    end

    it 'preserves dangling numeric references with their introducing fragment' do
      fragments = described_class.call("Goods of heading\n8481. C. Further text.")

      expect(fragments).to eq(['Goods of heading 8481.', 'C. Further text.'])
    end

    it 'does not merge ordinary numbered note markers into preceding prose' do
      fragments = described_class.call("This chapter covers goods.\n\n1. Definitions.")

      expect(fragments).to eq(['This chapter covers goods.', '1. Definitions.'])
    end
  end
end
