RSpec.describe Api::Admin::GoodsNomenclatureLabelsController do
  routes { AdminApi.routes }

  describe '#index' do
    let(:commodity_0101) { create(:commodity, goods_nomenclature_item_id: '0101210000') }
    let(:commodity_0201) { create(:commodity, goods_nomenclature_item_id: '0201100000') }
    let(:commodity_0301) { create(:commodity, goods_nomenclature_item_id: '0301110000') }

    before do
      create(:goods_nomenclature_label,
             goods_nomenclature: commodity_0101,
             labels: { 'description' => 'Live horses', 'known_brands' => %w[Thoroughbred], 'synonyms' => [], 'colloquial_terms' => [] },
             description: 'Live horses',
             known_brands: Sequel.pg_array(%w[Thoroughbred], :text),
             synonyms: Sequel.pg_array([], :text),
             colloquial_terms: Sequel.pg_array([], :text))
      create(:goods_nomenclature_label,
             goods_nomenclature: commodity_0201,
             labels: { 'description' => 'Fresh beef carcasses', 'known_brands' => [], 'synonyms' => ['bovine meat'], 'colloquial_terms' => [] },
             description: 'Fresh beef carcasses',
             known_brands: Sequel.pg_array([], :text),
             synonyms: Sequel.pg_array(['bovine meat'], :text),
             colloquial_terms: Sequel.pg_array([], :text))
      create(:goods_nomenclature_label,
             goods_nomenclature: commodity_0301,
             labels: { 'description' => 'Ornamental fish', 'known_brands' => [], 'synonyms' => [], 'colloquial_terms' => ['tropical fish'] },
             description: 'Ornamental fish',
             known_brands: Sequel.pg_array([], :text),
             synonyms: Sequel.pg_array([], :text),
             colloquial_terms: Sequel.pg_array(['tropical fish'], :text))
    end

    context 'when searching by commodity code prefix' do
      it 'returns labels matching the code prefix' do
        get :index, params: { q: '0101' }, format: :json

        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
        expect(json['data'].first.dig('attributes', 'goods_nomenclature_item_id')).to eq('0101210000')
      end

      it 'returns multiple results for broader prefixes' do
        get :index, params: { q: '02' }, format: :json

        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
        expect(json['data'].first.dig('attributes', 'goods_nomenclature_item_id')).to eq('0201100000')
      end
    end

    context 'when searching by text' do
      it 'matches label descriptions case-insensitively' do
        get :index, params: { q: 'horses' }, format: :json

        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
        expect(json['data'].first.dig('attributes', 'goods_nomenclature_item_id')).to eq('0101210000')
      end

      it 'matches known brands' do
        get :index, params: { q: 'Thoroughbred' }, format: :json

        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
        expect(json['data'].first.dig('attributes', 'goods_nomenclature_item_id')).to eq('0101210000')
      end

      it 'matches synonyms' do
        get :index, params: { q: 'bovine' }, format: :json

        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
        expect(json['data'].first.dig('attributes', 'goods_nomenclature_item_id')).to eq('0201100000')
      end

      it 'matches colloquial terms' do
        get :index, params: { q: 'tropical' }, format: :json

        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
        expect(json['data'].first.dig('attributes', 'goods_nomenclature_item_id')).to eq('0301110000')
      end
    end

    context 'when query is too short' do
      it 'returns empty results for single character' do
        get :index, params: { q: 'a' }, format: :json

        json = JSON.parse(response.body)
        expect(json['data']).to be_empty
      end
    end

    context 'when query is blank' do
      it 'returns empty results' do
        get :index, params: { q: '' }, format: :json

        json = JSON.parse(response.body)
        expect(json['data']).to be_empty
      end
    end

    context 'when no q param is provided' do
      it 'returns empty results' do
        get :index, format: :json

        json = JSON.parse(response.body)
        expect(json['data']).to be_empty
      end
    end

    it 'includes pagination meta' do
      get :index, params: { q: 'fish' }, format: :json

      json = JSON.parse(response.body)
      pagination = json.dig('meta', 'pagination')
      expect(pagination).to include('page', 'per_page', 'total_count')
    end

    context 'with pagination' do
      it 'respects per_page parameter' do
        get :index, params: { q: '03', per_page: 1 }, format: :json

        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
        expect(json.dig('meta', 'pagination', 'per_page')).to eq(1)
      end
    end
  end
end
