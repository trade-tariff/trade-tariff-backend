RSpec.describe Api::V2::BulkSearch::SearchResultSerializer do
  subject(:serializer) { described_class.new(search_ancestor) }

  let(:search_ancestor) do
    BulkSearch::SearchResult.build(
      short_code: '950720',
      goods_nomenclature_item_id: '9507200000',
      description: 'Fish-hooks, whether or not snelled',
      producline_suffix: '80',
      goods_nomenclature_class: 'Subheading',
      declarable: false,
      reason: 'matching_digit_ancestor',
      score: 32.99,
    )
  end

  describe '#serializable_hash' do
    subject(:serializable_hash) { serializer.serializable_hash }

    let(:pattern) do
      {
        data: {
          id: '950720-80-32.99',
          type: eq(:search_result_ancestor),
          attributes: {
            short_code: '950720',
            goods_nomenclature_item_id: '9507200000',
            description: 'Fish-hooks, whether or not snelled',
            producline_suffix: '80',
            goods_nomenclature_class: 'Subheading',
            declarable: false,
            reason: 'matching_digit_ancestor',
            score: 32.99,
          },
        },
      }
    end

    it { expect(serializable_hash).to match_json_expression(pattern) }
  end
end
