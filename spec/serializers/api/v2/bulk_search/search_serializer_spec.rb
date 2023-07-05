RSpec.describe Api::V2::BulkSearch::SearchSerializer do
  subject(:serializer) { described_class.new(search) }

  let(:search) do
    BulkSearch::Search.build(
      number_of_digits: 8,
      input_description: 'red herring',
      search_results: [
        {
          short_code: '950720',
          goods_nomenclature_item_id: '9507200000',
          description: 'Fish-hooks, whether or not snelled',
          producline_suffix: '80',
          goods_nomenclature_class: 'Subheading',
          declarable: false,
          reason: 'matching_digit_ancestor',
          score: 32.99,
        },
      ],
    )
  end

  describe '#serializable_hash' do
    subject(:serializable_hash) { serializer.serializable_hash }

    let(:pattern) do
      {
        data: {
          id: '28092073ed1b2c9697e79ac868175964',
          type: eq(:search),
          attributes: {
            number_of_digits: 8,
            input_description: 'red herring',
          },
          relationships: {
            search_results: {
              data: [
                { id: '950720-80-32.99', type: eq(:search_result_ancestor) },
              ],
            },
          },
        },
      }
    end

    it { expect(serializable_hash).to match_json_expression(pattern) }
  end
end
