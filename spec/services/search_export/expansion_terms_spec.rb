RSpec.describe SearchExport::ExpansionTerms do
  describe '.call' do
    it 'keeps an appended phrase containing a comma as one term' do
      expect(described_class.call(expansion_input: 'chicken', sent_query: 'chicken chicken cuts, frozen', synonym_terms: []))
        .to eq(['chicken cuts, frozen'])
    end

    it 'keeps a replaced query as one term' do
      expect(described_class.call(expansion_input: 'chicken', sent_query: 'frozen poultry meat', synonym_terms: []))
        .to eq(['frozen poultry meat'])
    end

    it 'does not count an unchanged retrieval query as expansion' do
      expect(described_class.call(expansion_input: 'chicken Fillet', sent_query: 'chicken Fillet', synonym_terms: []))
        .to eq([])
    end

    it 'keeps each synonym separately without guessing whether it is answer text' do
      expect(described_class.call(expansion_input: 'chicken', sent_query: 'chicken', synonym_terms: ['poultry', 'frozen meat', 'fillet']))
        .to eq(['poultry', 'frozen meat', 'fillet'])
    end
  end
end
