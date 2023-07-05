RSpec.describe Api::V2::BulkSearch::SearchResultSerializer do
  subject(:serializer) { described_class.new(search_result) }

  let(:search_result) do
    BulkSearch::SearchResult.build(
      number_of_digits: 6,
      short_code: '950720',
      score: 32.99,
    )
  end

  describe '#serializable_hash' do
    subject(:serializable_hash) { serializer.serializable_hash }

    let(:pattern) do
      {
        data: {
          id: '950720-32.99',
          type: eq(:search_result),
          attributes: {
            number_of_digits: 6,
            short_code: '950720',
            score: 32.99,
          },
        },
      }
    end

    it { expect(serializable_hash).to match_json_expression(pattern) }
  end
end
