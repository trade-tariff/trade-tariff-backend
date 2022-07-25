RSpec.describe Api::Beta::FacetClassificationStatisticSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) { build(:search_result, :clothing, :generate_facet_statistics).facet_filter_statistics.first.facet_classification_statistics }

    let(:expected) do
      {
        data: [
          {
            id: '639d3a406b0b1db74ce9250a4c71792d',
            type: :facet_classification_statistic,
            attributes: {
              facet: 'material',
              classification: 'cotton',
              count: 4,
            },
          },
        ],
      }
    end

    it { is_expected.to eq(expected) }
  end
end
