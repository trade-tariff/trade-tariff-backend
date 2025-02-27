require 'spec_helper'

RSpec.describe Sequel::Plugins::Elasticsearch do
  let(:commodity) { create :commodity }

  let(:search_result) do
    TradeTariffBackend.search_client.search q: query, index: Search::GoodsNomenclatureIndex.new.name
  end

  let(:query) do
    commodity.goods_nomenclature_item_id
  end

  let(:search_result_commodity_ids) do
    search_result.hits.hits.map(&:_source).map(&:goods_nomenclature_item_id)
  end

  let(:type) do
    search_result.hits.hits.map(&:_source).map(&:type)
  end

  let(:producline_suffix) do
    search_result.hits.hits.map(&:_source).map(&:producline_suffix)
  end

  before do
    TradeTariffBackend.search_client.drop_index(Search::GoodsNomenclatureIndex.new)
  end

  describe 'after_create a chapter' do
    context 'when an object is created' do
      let(:chapter) { create :chapter }

      let(:query) do
        chapter.goods_nomenclature_item_id
      end

      before { chapter.save }

      it 'indexes the created object' do
        expect(search_result.hits.total.value).to be >= 1
      end

      it 'includes the created object in the index' do
        expect(search_result_commodity_ids).to include chapter.goods_nomenclature_item_id
      end

      it 'includes the correct type in the index' do
        expect(type).to include chapter.class.name
      end
    end
  end

  describe 'after_create a heading' do
    context 'when an object is created' do
      let(:heading) { create :heading }

      let(:query) do
        heading.goods_nomenclature_item_id
      end

      before { heading.save }

      it 'indexes the created object' do
        expect(search_result.hits.total.value).to be >= 1
      end

      it 'includes the created object in the index' do
        expect(search_result_commodity_ids).to include heading.goods_nomenclature_item_id
      end

      it 'includes the correct type in the index' do
        expect(type).to include heading.class.name
      end
    end
  end

  describe 'after_create a commodity' do
    context 'when an object is created' do
      before { commodity.save }

      it 'indexes the created object' do
        expect(search_result.hits.total.value).to be >= 1
      end

      it 'includes the created object in the index' do
        expect(search_result_commodity_ids).to include commodity.goods_nomenclature_item_id
      end

      it 'includes the correct type in the index' do
        expect(type).to include commodity.class.name
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
    let(:search_reference) { create :search_reference }

    let(:search_reference_title) do
      search_result.hits.hits.map(&:_source).map(&:search_references).first.map(&:title)
    end

    let(:query) { search_reference.title }

    context 'when a search reference is created' do
      before { search_reference.save }

      it 'indexes the referenced goods nomenclatures' do
        expect(search_result.hits.total.value).to be >= 1
      end

      it 'includes the reference title in the index' do
        expect(search_reference_title).to include search_reference.title
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

  describe 'Chemicals behavior' do
    let(:chemical) { create :full_chemical }

    let(:chemical_name) do
      search_result.hits.hits.map(&:_source).map(&:chemicals).first.map(&:name)
    end

    let(:query) { chemical.name }

    context 'when a search reference is created' do
      before { chemical.save }

      it 'indexes the referenced goods nomenclatures' do
        expect(search_result.hits.total.value).to be >= 1
      end

      it 'includes the chemical name in the index' do
        expect(chemical_name).to include chemical.name
      end
    end

    context 'when a chemical is destroyed' do
      before do
        chemical.save
        chemical.destroy
      end

      it 'removes the referenced goods nomenclatures from the index' do
        expect(search_result.hits.hits.flat_map { |hit| hit._source.chemicals || [] }.size).to eq 0
      end
    end
  end
end
