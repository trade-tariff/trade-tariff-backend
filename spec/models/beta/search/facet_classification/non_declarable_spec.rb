RSpec.describe Beta::Search::FacetClassification::NonDeclarable do
  describe '.build' do
    subject(:result) { described_class.build(build(:commodity)) }

    it { is_expected.to be_a(Beta::Search::FacetClassification) }
    it { expect(result.classifications).to eq({}) }
  end
end
