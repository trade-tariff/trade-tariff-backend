RSpec.describe SpellingCorrector::Loaders::OriginReference do
  include_context 'with a stubbed spelling corrector bucket'

  describe '#load' do
    subject(:load) { described_class.new.load }

    let(:expected_terms) do
      {
        'the' => 6,
        'and' => 5,
        'agreement' => 3,
        'ireland' => 2,
        'northern' => 2,
        'britain' => 2,
        'great' => 2,
        'kingdom' => 2,
        'united' => 2,
        'between' => 2,
        'establishing' => 2,
        'implementing' => 2,
        'document' => 2,
        'reference' => 2,
        'origin' => 2,
        'georgia' => 1,
        'cooperation' => 1,
        'partnership' => 1,
        'strategic' => 1,
        'tunisia' => 1,
        'republic' => 1,
        'association' => 1,
      }
    end

    it { is_expected.to eq(expected_terms) }
  end
end
