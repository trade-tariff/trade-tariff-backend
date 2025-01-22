require 'spec_helper'

RSpec.describe Sequel::Plugins::Elasticsearch do
  let(:commodity) { create :commodity }
  let(:search_reference) { create :search_reference }

  let(:search_result) do
    TradeTariffBackend.search_client.search q: query, index: Search::GoodsNomenclatureIndex.new.name
  end

  let(:query) do
    commodity.goods_nomenclature_item_id
  end

  let(:search_result_commodity_ids) do
    search_result.hits.hits.map(&:_source).map(&:goods_nomenclature_item_id)
  end

  let(:producline_suffix) do
    search_result.hits.hits.map(&:_source).map(&:producline_suffix)
  end

  let(:search_reference_title) do
    search_result.hits.hits.map(&:_source).map(&:search_references).first.map(&:title)
  end

  before do
    TradeTariffBackend.search_client.drop_index(Search::GoodsNomenclatureIndex.new)
  end

  describe 'after_create' do
    it 'indexes the created object' do
      commodity.save

      expect(search_result.hits.total.value).to be >= 1
      expect(search_result_commodity_ids).to include commodity.goods_nomenclature_item_id
    end
  end

  describe 'after_update' do
    it 'updates the index for the object' do
      commodity.save # Create first
      commodity.update(producline_suffix: '70')

      expect(search_result.hits.total.value).to be >= 1
      expect(producline_suffix).to include commodity.producline_suffix
    end
  end

  describe 'after_destroy' do
    it 'removes the object from the index' do
      commodity.save # Create first
      commodity.destroy

      expect(search_result.hits.total.value).to eq 0
    end
  end

  describe 'SearchReference behavior' do
    let(:query) do
      search_reference.title
    end

    it 'indexes referenced goods nomenclatures on creation' do
      search_reference.save

      expect(search_result.hits.total.value).to be >= 1
      expect(search_reference_title).to include search_reference.title
    end

    it 'removes referenced goods nomenclatures from index on destruction' do
      search_reference.save
      search_reference.destroy

      expect(search_result.hits.hits.map(&:_source).map(&:search_references).size).to eq 0
    end
  end
end
