RSpec.describe GenerateSelfText::EncodingArtefactSanitiser do
  describe '.call' do
    it 'returns text unchanged when no artefacts are present' do
      expect(described_class.call('Fruit juice and vegetable juice')).to eq('Fruit juice and vegetable juice')
    end

    it 'returns nil unchanged' do
      expect(described_class.call(nil)).to be_nil
    end

    it 'returns blank string unchanged' do
      expect(described_class.call('')).to eq('')
    end

    it 'corrects pure9e to puree' do
      expect(described_class.call('Fruit pure9e')).to eq('Fruit puree')
    end

    it 'handles multiple occurrences in one string' do
      expect(described_class.call('pure9e and pure9e concentrate')).to eq('puree and puree concentrate')
    end

    it 'does not modify unrelated text containing 9e' do
      expect(described_class.call('19e century trade goods')).to eq('19e century trade goods')
    end
  end
end
