RSpec.describe Beta::Search::GoodsNomenclatureQuery do
  describe '.build' do
    subject(:result) { described_class.build(search_query_parser_result) }

    let(:search_query_parser_result) { build(:search_query_parser_result) }

    it { is_expected.to be_a(described_class) }
  end

  describe '#id' do
    subject(:id) { build(:goods_nomenclature_query, :full_query).id }

    it { is_expected.to eq('cbbc8118105b8e1c3cb4bb74a978fa83') }
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

    context 'when the search query is a numeric' do
      subject(:goods_nomenclature_query) { build(:goods_nomenclature_query, :numeric).query }

      let(:expected_query) do
        {
          query: {
            term: {
              goods_nomenclature_item_id: {
                value: '0101000000',
              },
            },
          },
        }
      end

      it { is_expected.to eq(expected_query) }
    end

    context 'when there are nouns, noun_chunks, verbs and adjectives' do
      subject(:goods_nomenclature_query) { build(:goods_nomenclature_query, :full_query).query }

      let(:expected_query) do
        {
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
          size: '10',
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
          size: '10',
          query: {
            bool: {
              must: [
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
          size: '10',
          query: {
            bool: {
              must: [
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

    context 'when a filter is included' do
      subject(:goods_nomenclature_query) { build(:goods_nomenclature_query, :filter).query }

      let(:expected_query) do
        {
          size: '10',
          query: {
            bool: {
              filter: {
                bool: {
                  must: [
                    {
                      terms: {
                        filter_cheese_type: [
                          'containing veins produced by Penicillium roqueforti|fresh|grated or powdered|processed',
                          'fresh|grated or powdered|processed',
                          'fresh|processed',
                          'fresh',
                        ],
                        boost: 1,
                      },
                    },
                  ],
                },
              },
              must: [
                {
                  multi_match: {
                    query: 'ricotta',
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

      it 'calls out to the filter generator service with the correct filters' do
        allow(Api::Beta::GoodsNomenclatureFilterGeneratorService).to receive(:new).and_call_original

        goods_nomenclature_query

        expect(Api::Beta::GoodsNomenclatureFilterGeneratorService).to have_received(:new).with('cheese_type' => 'fresh')
      end
    end
  end

  describe '#goods_nomenclature_item_id' do
    subject(:goods_nomenclature_query) { build(:goods_nomenclature_query, :numeric, original_search_query: search_query) }

    context 'when search query is shorter than 10 digits' do
      let(:search_query) { '0101' }

      it 'returns the padded original_search_query' do
        expect(goods_nomenclature_query.goods_nomenclature_item_id).to eq('0101000000')
      end
    end

    context 'when search query is longer than 10 digits' do
      let(:search_query) { '010100000012' }

      it 'returns the original original_search_query' do
        expect(goods_nomenclature_query.goods_nomenclature_item_id).to eq(search_query)
      end
    end
  end

  describe '#numeric?' do
    context 'when the numeric value is set' do
      subject(:goods_nomenclature_query) { build(:goods_nomenclature_query, :numeric) }

      it { is_expected.to be_numeric }
    end

    context 'when the numeric value is not set' do
      subject(:goods_nomenclature_query) { build(:goods_nomenclature_query) }

      it { is_expected.not_to be_numeric }
    end
  end
end
