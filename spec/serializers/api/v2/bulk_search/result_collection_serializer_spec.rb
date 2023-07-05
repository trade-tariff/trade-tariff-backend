RSpec.describe Api::V2::BulkSearch::ResultCollectionSerializer do
  subject(:serializer) { described_class.new(result_collection) }

  let(:result_collection) do
    BulkSearch::ResultCollection.new(
      id: '1234',
      status: 'complete',
      searches: [
        {
          number_of_digits: 8,
          input_description: 'red herring',
          search_results: [
            {
              number_of_digits: 6,
              short_code: '950720',
              score: 32.99,
            },
          ],
        },
        {
          number_of_digits: 8,
          input_description: 'white bait',
          search_results: [
            {
              number_of_digits: 6,
              short_code: '160420',
              score: 25.97,
            },
          ],
        },
      ],
    )
  end

  describe '#serializable_hash' do
    subject(:serializable_hash) { serializer.serializable_hash }

    let(:pattern) do
      {
        data: {
          id: '1234',
          type: eq(:result_collection),
          attributes: { status: 'complete', message: nil },
          relationships: {
            searches: {
              data: [
                { id: '28092073ed1b2c9697e79ac868175964', type: eq(:search) },
                { id: '7df0f64c426cfa31817c32511c0fce16', type: eq(:search) },
              ],
            },
          },
        },
      }
    end

    it { expect(serializable_hash).to match_json_expression(pattern) }
  end
end
