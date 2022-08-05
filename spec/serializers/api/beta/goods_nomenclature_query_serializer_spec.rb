RSpec.describe Api::Beta::GoodsNomenclatureQuerySerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(serializable).serializable_hash }

    let(:serializable) { build(:goods_nomenclature_query, :full_query) }

    let(:expected) do
      {
        data: {
          id: 'cbbc8118105b8e1c3cb4bb74a978fa83',
          type: :goods_nomenclature_query,
          attributes: {
            query: {
              size: '10',
              query: {
                bool: {
                  must: [
                    {
                      multi_match: {
                        query: 'man',
                        fuzziness: 0.1,
                        prefix_length: 2,
                        tie_breaker: 0.3,
                        type: 'best_fields',
                        fields: [
                          'search_references^12',
                          'ancestor_1_description_indexed^10',
                          'ancestor_2_description_indexed^8',
                          'description_indexed^6',
                          'ancestor_3_description_indexed^4',
                          'ancestor_4_description_indexed^4',
                          'ancestor_5_description_indexed^4',
                          'ancestor_6_description_indexed^4',
                          'ancestor_7_description_indexed^4',
                          'ancestor_8_description_indexed^4',
                          'ancestor_9_description_indexed^4',
                          'ancestor_10_description_indexed^4',
                          'ancestor_11_description_indexed^4',
                          'ancestor_12_description_indexed^4',
                          'ancestor_13_description_indexed^4',
                          'goods_nomenclature_item_id',
                        ],
                      },
                    },
                  ],
                  should: [
                    {
                      multi_match: {
                        query: 'run',
                        fuzziness: 0.1,
                        prefix_length: 2,
                        tie_breaker: 0.3,
                        type: 'best_fields',
                        fields: [
                          'search_references^12',
                          'ancestor_1_description_indexed^10',
                          'ancestor_2_description_indexed^8',
                          'description_indexed^6',
                          'ancestor_3_description_indexed^4',
                          'ancestor_4_description_indexed^4',
                          'ancestor_5_description_indexed^4',
                          'ancestor_6_description_indexed^4',
                          'ancestor_7_description_indexed^4',
                          'ancestor_8_description_indexed^4',
                          'ancestor_9_description_indexed^4',
                          'ancestor_10_description_indexed^4',
                          'ancestor_11_description_indexed^4',
                          'ancestor_12_description_indexed^4',
                          'ancestor_13_description_indexed^4',
                          'goods_nomenclature_item_id',
                        ],
                      },
                    },
                    {
                      multi_match: {
                        query: 'tall',
                        fuzziness: 0.1,
                        prefix_length: 2,
                        tie_breaker: 0.3,
                        type: 'best_fields',
                        fields: [
                          'search_references^12',
                          'ancestor_1_description_indexed^10',
                          'ancestor_2_description_indexed^8',
                          'description_indexed^6',
                          'ancestor_3_description_indexed^4',
                          'ancestor_4_description_indexed^4',
                          'ancestor_5_description_indexed^4',
                          'ancestor_6_description_indexed^4',
                          'ancestor_7_description_indexed^4',
                          'ancestor_8_description_indexed^4',
                          'ancestor_9_description_indexed^4',
                          'ancestor_10_description_indexed^4',
                          'ancestor_11_description_indexed^4',
                          'ancestor_12_description_indexed^4',
                          'ancestor_13_description_indexed^4',
                          'goods_nomenclature_item_id',
                        ],
                      },
                    },
                  ],
                },
              },
            },
          },
        },
      }
    end

    it { is_expected.to eq(expected) }
  end
end
