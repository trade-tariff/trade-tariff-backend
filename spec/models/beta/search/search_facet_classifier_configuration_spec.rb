RSpec.describe Beta::Search::SearchFacetClassifierConfiguration do
  describe '.each_classification' do
    context 'when passed a block' do
      it { expect { |block| described_class.each_classification(&block) }.to yield_control.exactly(69).times }
    end

    context 'when not passed a block' do
      subject(:each_classification) { described_class.each_classification }

      it { is_expected.to be_nil }
    end
  end

  describe '.heading_facet_mappings' do
    subject(:heading_facet_mappings) { described_class.heading_facet_mappings.keys.count }

    it { is_expected.to eq(1230) }
  end
end
