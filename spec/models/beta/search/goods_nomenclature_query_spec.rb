RSpec.describe Beta::Search::GoodsNomenclatureQuery do
  describe '.build' do
    subject(:result) { described_class.build(search_query_parser_result) }

    let(:search_query_parser_result) { build(:search_query_parser_result) }

    it { is_expected.to be_a(described_class) }
  end

  describe '#query' do
    let(:expected_multi_match_fields) do
      [
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
      ]
    end

    context 'when there are nouns, noun_chunks, verbs and adjectives' do
      subject(:goods_nomenclature_query) { build(:goods_nomenclature_query, :full_query).query }

      let(:expected_query) do
        {
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
                    fields: expected_multi_match_fields,
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
                    fields: expected_multi_match_fields,
                  },
                },
                {
                  multi_match: {
                    query: 'tall',
                    fuzziness: 0.1,
                    prefix_length: 2,
                    tie_breaker: 0.3,
                    type: 'best_fields',
                    fields: expected_multi_match_fields,
                  },
                },
              ],
            },
          },
        }
      end

      it { is_expected.to eq(expected_query) }
    end

    context 'when there are only nouns' do
      subject(:goods_nomenclature_query) { build(:goods_nomenclature_query, nouns: %w[man]).query }

      let(:expected_query) do
        {
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
                    fields: expected_multi_match_fields,
                  },
                },
              ],
            },
          },
        }
      end

      it { is_expected.to eq(expected_query) }
    end

    context 'when there are only noun_chunks' do
      subject(:goods_nomenclature_query) { build(:goods_nomenclature_query, noun_chunks: ['clothing sets']).query }

      let(:expected_query) do
        {
          query: {
            bool: {
              must: [
                {
                  multi_match: {
                    query: 'clothing sets',
                    fuzziness: 0.1,
                    prefix_length: 2,
                    tie_breaker: 0.3,
                    type: 'best_fields',
                    fields: expected_multi_match_fields,
                  },
                },
              ],
            },
          },
        }
      end

      it { is_expected.to eq(expected_query) }
    end

    context 'when there are only verbs' do
      subject(:goods_nomenclature_query) { build(:goods_nomenclature_query, verbs: %w[running]).query }

      let(:expected_query) do
        {
          query: {
            bool: {
              should: [
                {
                  multi_match: {
                    query: 'running',
                    fuzziness: 0.1,
                    prefix_length: 2,
                    tie_breaker: 0.3,
                    type: 'best_fields',
                    fields: expected_multi_match_fields,
                  },
                },
              ],
            },
          },
        }
      end

      it { is_expected.to eq(expected_query) }
    end

    context 'when there are only adjectives' do
      subject(:goods_nomenclature_query) { build(:goods_nomenclature_query, verbs: %w[tall]).query }

      let(:expected_query) do
        {
          query: {
            bool: {
              should: [
                {
                  multi_match: {
                    query: 'tall',
                    fuzziness: 0.1,
                    prefix_length: 2,
                    tie_breaker: 0.3,
                    type: 'best_fields',
                    fields: expected_multi_match_fields,
                  },
                },
              ],
            },
          },
        }
      end

      it { is_expected.to eq(expected_query) }
    end
  end
end
