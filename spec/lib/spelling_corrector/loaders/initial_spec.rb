RSpec.describe SpellingCorrector::Loaders::Initial do
  include_context 'with a stubbed spelling corrector bucket'

  describe '#load' do
    subject(:load) { described_class.new.load }

    let(:expected_terms) do
      {
        'aardvark' => 2,
        'aardvarks' => 1,
        'aardwolf' => 1,
        'aare' => 1,
        'aarhus' => 1,
        'aaron' => 3,
        'aarp' => 1,
        'aas' => 1,
        'aat' => 1,
      }
    end

    it { is_expected.to eq(expected_terms) }
  end
end
