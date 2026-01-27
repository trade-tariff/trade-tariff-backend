RSpec.describe Search::Fuzzy::GoodsNomenclatureQuery do
  describe '#query' do
    subject(:query) { described_class.new(query_string, date, index).query }

    let(:query_string) { 'foo' }
    let(:date) { Time.zone.today }
    let(:index) { Search::CommodityIndex.new }

    let(:pattern) do
      {
        index: 'tariff-test-commodities-uk',
        search: {
          query: {
            bool: {
              must: [
                { bool: { must_not: { terms: { goods_nomenclature_item_id: [] } } } },
                { multi_match: { query: 'foo', operator: 'and', fields: %w[description_indexed] } },
              ],
            },
          },
        },
      }
    end

    it { is_expected.to include_json pattern }
  end

  describe '#match_type' do
    it 'returns :goods_nomenclature_match' do
      instance = described_class.new('test', Time.zone.today, Search::CommodityIndex.new)
      expect(instance.match_type).to eq(:goods_nomenclature_match)
    end
  end
end
