RSpec.describe SpellingCorrector::Loaders::Synonyms do
  describe '#load' do
    subject(:load) { described_class.new.load }

    let(:expected_terms) do
      {
        'chiliad' => 1,
        'grand' => 1,
        'abyssinian' => 2,
        'cat' => 53,
      }
    end

    it { is_expected.to include(expected_terms) }
  end
end
