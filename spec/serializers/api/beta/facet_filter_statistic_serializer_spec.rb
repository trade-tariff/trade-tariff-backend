RSpec.describe Api::Beta::FacetFilterStatisticSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) { build(:search_result, :clothing, :generate_facet_statistics).facet_filter_statistics }

    let(:expected) do
      {
        data: [
          {
            id: '2ecbb6c19ee6282b0c79dda2aeaf0192',
            type: :facet_filter_statistic,
            attributes: {
              facet_filter: 'filter_material',
              facet_count: 4,
              display_name: 'Material',
              question: 'Pick one of Material',
            },
            relationships: {
              facet_classification_statistics: {
                data: [
                  { id: '639d3a406b0b1db74ce9250a4c71792d', type: :facet_classification_statistic },
                ],
              },
            },
          },
          {
            id: 'b24e66a126ad13c1521cf6cda4b2c502',
            type: :facet_filter_statistic,
            attributes: {
              facet_filter: 'filter_clothing_gender',
              facet_count: 2,
              display_name: 'Clothing gender',
              question: 'Pick one of Clothing gender',
            },
            relationships: {
              facet_classification_statistics: {
                data: [
                  { id: '0f9f895e9a6bb156694dd9c8bca33545', type: :facet_classification_statistic },
                ],
              },
            },
          },
          {
            id: 'b030d559d41aee55d3cd439888aa5edf',
            type: :facet_filter_statistic,
            attributes: {
              facet_filter: 'filter_garment_type',
              facet_count: 2,
              display_name: 'Garment type',
              question: 'Pick one of Garment type',
            },
            relationships: {
              facet_classification_statistics: {
                data: [
                  { id: 'e1ff51f7d55ca6f6bbfb508996d174b1', type: :facet_classification_statistic },
                  { id: '52fe3def5c7edf22d27bfa0b2fc63208', type: :facet_classification_statistic },
                ],
              },
            },
          },
        ],
      }
    end

    it { is_expected.to eq(expected) }
  end
end
