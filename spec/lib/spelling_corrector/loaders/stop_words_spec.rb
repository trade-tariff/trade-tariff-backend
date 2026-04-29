RSpec.describe SpellingCorrector::Loaders::StopWords do
  describe '#load' do
    subject(:load) { described_class.new.load }

    let(:expected_terms) do
      {
        'them' => 1,
        'themselves' => 1,
        'then' => 1,
        'thence' => 1,
        'there' => 1,
        "there'll" => 1,
        "there've" => 1,
        'thereafter' => 1,
      }
    end

    it { is_expected.to include(expected_terms) }
  end
end
