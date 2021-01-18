require 'rails_helper'

describe TradeTariffBackend::SearchClient do
  describe '#search' do
    let(:commodity) do
      create :commodity, :with_description, description: 'test description'
    end

    let(:search_result) do
      TradeTariffBackend.search_client.search q: 'test', index: TradeTariffBackend.search_index_for('search', commodity).name
    end

    it 'searches in supplied index' do
      expect(search_result.hits.total.value).to be >= 1
      expect(search_result.hits.hits.map do |hit|
        hit._source.goods_nomenclature_item_id
      end).to include commodity.goods_nomenclature_item_id
    end

    it 'returns results wrapped in Hashie::Mash structure' do
      expect(search_result).to be_kind_of Hashie::Mash
    end
  end
end
