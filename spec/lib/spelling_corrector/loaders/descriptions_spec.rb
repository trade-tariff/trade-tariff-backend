RSpec.describe SpellingCorrector::Loaders::Descriptions do
  describe '#load' do
    subject(:load) { described_class.new.load }

    before do
      create(:goods_nomenclature, :actual, :with_description, description: 'A current description Flibble fladasd@!@#!@')
      create(:goods_nomenclature, :expired, :with_description, description: 'A non-current description With Somasda terms in it')
    end

    let(:expected_terms) do
      {
        'current' => 1,
        'description' => 1,
        'fladasd' => 1,
        'flibble' => 1,
      }
    end

    it { is_expected.to eq(expected_terms) }
  end
end
