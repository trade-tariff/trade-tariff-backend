RSpec.describe SearchService::FuzzySearch::GoodsNomenclatureQuery do
  describe '#query' do
    subject(:query) { described_class.new(query_string, date, index).query }

    let(:query_string) { 'foo' }
    let(:date) { Time.zone.today }
    let(:index) { Commodity.elasticsearch_index }

    context 'when the legacy search enhancements are enabled' do
      before { allow(TradeTariffBackend).to receive(:legacy_search_enhancements_enabled?).and_return(true) }

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

    context 'when the legacy search enhancements are disabled' do
      before { allow(TradeTariffBackend).to receive(:legacy_search_enhancements_enabled?).and_return(false) }

      let(:pattern) do
        {
          index: 'tariff-test-commodities-uk',
          search: {
            query: {
              bool: {
                must: [
                  { bool: { must_not: { terms: { goods_nomenclature_item_id: [] } } } },
                  { multi_match: { query: 'foo', operator: 'and', fields: %w[description] } },
                ],
              },
            },
          },
        }
      end

      it { is_expected.to include_json pattern }
    end
  end
end
