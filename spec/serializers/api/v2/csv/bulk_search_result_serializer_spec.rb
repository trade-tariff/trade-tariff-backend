RSpec.describe Api::V2::Csv::BulkSearchResultSerializer do
  describe '#serializable_array' do
    subject(:serializable_array) { described_class.new([serializable]).serializable_array }

    let(:serializable) do
      Api::V2::BulkSearchResultPresenter.new(
        search,
        search_result,
      )
    end

    let(:search) { build(:bulk_search) }
    let(:search_result) { search.search_results.first }

    it 'serializes correctly' do
      expect(serializable_array).to eq(
        [
          %i[input_description number_of_digits short_code score],
          [
            search.input_description,
            search_result.number_of_digits,
            search_result.short_code,
            search_result.score,
          ],
        ],
      )
    end
  end
end
