RSpec.describe Api::V2::BulkSearch::SearchSerializer do
  subject(:serializer) { described_class.new(search) }

  let(:search) do
    BulkSearch::Search.build(
      number_of_digits: 6,
      input_description: 'red herring',
      search_results: [
        {
          number_of_digits: 6,
          short_code: '950720',
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
            number_of_digits: 6,
            input_description: 'red herring',
          },
          relationships: {
            search_results: {
              data: [
                { id: '950720-32.99', type: eq(:search_result) },
              ],
            },
          },
        },
      }
    end

    it { expect(serializable_hash).to match_json_expression(pattern) }
  end
end
