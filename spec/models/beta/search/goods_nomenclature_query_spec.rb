RSpec.describe Beta::Search::GoodsNomenclatureQuery do
  describe '.build' do
    subject(:result) { described_class.build(search_query_parser_result) }

    let(:search_query_parser_result) { build(:search_query_parser_result) }

    it { is_expected.to be_a(described_class) }
  end

  describe '#query' do
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
                    fields: [
                      'search_references^12',
                      'chapter_description^10',
                      'heading_description^8',
                      'description.exact^6',
                      'description_indexed^6',
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
                      'chapter_description^10',
                      'heading_description^8',
                      'description.exact^6',
                      'description_indexed^6',
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
                      'chapter_description^10',
                      'heading_description^8',
                      'description.exact^6',
                      'description_indexed^6',
                      'goods_nomenclature_item_id',
                    ],
                  },
                },
              ],
            },
          },
        }
      end

      it { is_expected.to eq(expected_query) }
    end

    context 'when there are nouns' do
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
                    fields: [
                      'search_references^12',
                      'chapter_description^10',
                      'heading_description^8',
                      'description.exact^6',
                      'description_indexed^6',
                      'goods_nomenclature_item_id',
                    ],
                  },
                },
              ],
            },
          },
        }
      end

      it { is_expected.to eq(expected_query) }
    end

    context 'when there are noun_chunks' do
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
                    fields: [
                      'search_references^12',
                      'chapter_description^10',
                      'heading_description^8',
                      'description.exact^6',
                      'description_indexed^6',
                      'goods_nomenclature_item_id',
                    ],
                  },
                },
              ],
            },
          },
        }
      end

      it { is_expected.to eq(expected_query) }
    end

    context 'when there are verbs' do
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
                    fields: [
                      'search_references^12',
                      'chapter_description^10',
                      'heading_description^8',
                      'description.exact^6',
                      'description_indexed^6',
                      'goods_nomenclature_item_id',
                    ],
                  },
                },
              ],
            },
          },
        }
      end

      it { is_expected.to eq(expected_query) }
    end

    context 'when there are adjectives' do
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
                    fields: [
                      'search_references^12',
                      'chapter_description^10',
                      'heading_description^8',
                      'description.exact^6',
                      'description_indexed^6',
                      'goods_nomenclature_item_id',
                    ],
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
