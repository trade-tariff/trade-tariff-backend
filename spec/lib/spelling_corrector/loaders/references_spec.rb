RSpec.describe SpellingCorrector::Loaders::References do
  describe '#load' do
    subject(:load) { described_class.new.load }

    before do
      create(:search_reference, title: 'hello there search, reference (with some stuff in it) That IS capitalized hello')
    end

    let(:expected_terms) do
      {
        'capitalized' => 1,
        'hello' => 2,
        'reference' => 1,
        'search' => 1,
        'some' => 1,
        'stuff' => 1,
        'that' => 1,
        'there' => 1,
        'with' => 1,
      }
    end

    it { is_expected.to eq(expected_terms) }
  end
end
