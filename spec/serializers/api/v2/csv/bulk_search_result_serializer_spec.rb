RSpec.describe Api::V2::Csv::BulkSearchResultSerializer do
  describe '#serializable_array' do
    subject(:serializable_array) { described_class.new([serializable]).serializable_array }

    let(:serializable) do
      Api::V2::BulkSearchResultPresenter.new(
        search,
        search_result_ancestor,
      )
    end

    let(:search) { build(:bulk_search) }
    let(:search_result_ancestor) { search.search_results.first }

    it 'serializes correctly' do
      expect(serializable_array).to eq(
        [
          %i[input_description goods_nomenclature_item_id producline_suffix goods_nomenclature_class short_code score],
          [
            search.input_description,
            search_result_ancestor.goods_nomenclature_item_id,
            search_result_ancestor.producline_suffix,
            search_result_ancestor.goods_nomenclature_class,
            search_result_ancestor.short_code,
            search_result_ancestor.score,
          ],
        ],
      )
    end
  end
end
