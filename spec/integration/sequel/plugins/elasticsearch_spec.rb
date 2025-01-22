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
    context 'when an object is created' do
      before { commodity.save }

      it 'indexes the created object' do
        expect(search_result.hits.total.value).to be >= 1
      end

      it 'includes the created object in the index' do
        expect(search_result_commodity_ids).to include commodity.goods_nomenclature_item_id
      end
    end
  end

  describe 'after_update' do
    before do
      commodity.save
      commodity.update(producline_suffix: '70')
    end

    context 'when an object is updated' do
      it 'updates the index for the object' do
        expect(search_result.hits.total.value).to be >= 1
      end

      it 'reflects the updated field in the index' do
        expect(producline_suffix).to include commodity.producline_suffix
      end
    end
  end

  describe 'after_destroy' do
    before do
      commodity.save
      commodity.destroy
    end

    it 'removes the object from the index' do
      expect(search_result.hits.total.value).to eq 0
    end
  end

  describe 'SearchReference behavior' do
    let(:query) { search_reference.title }

    context 'when a search reference is created' do
      before { search_reference.save }

      it 'indexes the referenced goods nomenclatures' do
        expect(search_result.hits.total.value).to be >= 1
      end

      it 'includes the reference title in the index' do
        expect(search_reference_titles).to include search_reference.title
      end
    end

    context 'when a search reference is destroyed' do
      before do
        search_reference.save
        search_reference.destroy
      end

      it 'removes the referenced goods nomenclatures from the index' do
        expect(search_result.hits.hits.flat_map { |hit| hit._source.search_references || [] }.size).to eq 0
      end
    end
  end
end
