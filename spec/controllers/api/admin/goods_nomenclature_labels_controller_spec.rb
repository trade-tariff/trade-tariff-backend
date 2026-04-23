RSpec.describe Api::Admin::GoodsNomenclatureLabelsController do
  routes { AdminApi.routes }

  describe '#index' do
    let!(:commodity) do
      create(:goods_nomenclature, producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX).tap do |gn|
        create(:goods_nomenclature_label,
               goods_nomenclature: gn,
               description: 'Live horses',
               description_score: 0.5,
               known_brands: Sequel.pg_array(%w[Thoroughbred], :text),
               synonyms: Sequel.pg_array([], :text),
               colloquial_terms: Sequel.pg_array([], :text),
               stale: false,
               manually_edited: false,
               labels: { 'description' => 'Live horses' })
      end
    end

    let!(:subheading) do # rubocop:disable RSpec/LetSetup
      create(:goods_nomenclature, producline_suffix: '10').tap do |gn|
        create(:goods_nomenclature_label,
               goods_nomenclature: gn,
               description: 'Fresh beef carcasses',
               description_score: 0.9,
               known_brands: Sequel.pg_array([], :text),
               synonyms: Sequel.pg_array(['bovine meat'], :text),
               colloquial_terms: Sequel.pg_array([], :text),
               stale: true,
               manually_edited: false,
               labels: { 'description' => 'Fresh beef carcasses' })
      end
    end

    it 'returns all labels' do
      get :index, format: :json

      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(2)
    end

    it 'includes score attribute' do
      get :index, format: :json

      json = JSON.parse(response.body)
      scores = json['data'].map { |d| d.dig('attributes', 'description_score') }
      expect(scores).to contain_exactly(0.5, 0.9)
    end

    it 'sorts by score ascending by default' do
      get :index, format: :json

      json = JSON.parse(response.body)
      scores = json['data'].map { |d| d.dig('attributes', 'description_score') }
      expect(scores).to eq([0.5, 0.9])
    end

    it 'includes pagination meta' do
      get :index, format: :json

      json = JSON.parse(response.body)
      pagination = json.dig('meta', 'pagination')
      expect(pagination['page']).to eq(1)
      expect(pagination['total_count']).to eq(2)
    end

    context 'with status filter' do
      it 'filters to stale' do
        get :index, params: { status: 'stale' }, format: :json

        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
        expect(json['data'].first.dig('attributes', 'stale')).to be true
      end

      it 'filters to manually_edited' do
        get :index, params: { status: 'manually_edited' }, format: :json

        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(0)
      end
    end

    context 'with approved records' do
      let!(:approved_commodity) do
        create(:goods_nomenclature, producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX).tap do |gn|
          create(:goods_nomenclature_label,
                 goods_nomenclature: gn,
                 description: 'Approved label for direct lookup',
                 description_score: 0.4,
                 known_brands: Sequel.pg_array([], :text),
                 synonyms: Sequel.pg_array([], :text),
                 colloquial_terms: Sequel.pg_array([], :text),
                 approved: true,
                 labels: { 'description' => 'Approved label for direct lookup' })
        end
      end

      it 'excludes approved labels from normal listing by default' do
        get :index, format: :json

        json = JSON.parse(response.body)
        sids = json['data'].map { |d| d.dig('attributes', 'goods_nomenclature_sid') }
        expect(sids).not_to include(approved_commodity.goods_nomenclature_sid)
      end

      it 'returns approved labels when explicitly filtered' do
        get :index, params: { status: 'approved' }, format: :json

        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
        expect(json['data'].first.dig('attributes', 'approved')).to be true
      end

      it 'keeps approved labels searchable by text' do
        get :index, params: { q: 'direct lookup' }, format: :json

        json = JSON.parse(response.body)
        sids = json['data'].map { |d| d.dig('attributes', 'goods_nomenclature_sid') }
        expect(sids).to include(approved_commodity.goods_nomenclature_sid)
      end
    end

    context 'with score_category filter' do
      let!(:low_score) do # rubocop:disable RSpec/LetSetup
        create(:goods_nomenclature, producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX).tap do |gn|
          create(:goods_nomenclature_label,
                 goods_nomenclature: gn,
                 description: 'Bad label',
                 description_score: 0.2,
                 known_brands: Sequel.pg_array([], :text),
                 synonyms: Sequel.pg_array([], :text),
                 colloquial_terms: Sequel.pg_array([], :text),
                 labels: { 'description' => 'Bad label' })
        end
      end

      it 'filters to bad scores (below 0.3)' do
        get :index, params: { score_category: 'bad' }, format: :json

        json = JSON.parse(response.body)
        scores = json['data'].map { |d| d.dig('attributes', 'description_score') }
        expect(scores).to all(be < 0.3)
      end

      it 'filters to good scores (0.5 to 0.85)' do
        get :index, params: { score_category: 'good' }, format: :json

        json = JSON.parse(response.body)
        scores = json['data'].map { |d| d.dig('attributes', 'description_score') }
        expect(scores).to all(be >= 0.5)
        expect(scores).to all(be < 0.85)
      end

      it 'filters to amazing scores (0.85+)' do
        get :index, params: { score_category: 'amazing' }, format: :json

        json = JSON.parse(response.body)
        scores = json['data'].map { |d| d.dig('attributes', 'description_score') }
        expect(scores).to all(be >= 0.85)
      end

      it 'filters to records with no score' do
        create(:goods_nomenclature, producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX).tap do |gn|
          create(:goods_nomenclature_label,
                 goods_nomenclature: gn,
                 description: 'No score label',
                 description_score: nil,
                 known_brands: Sequel.pg_array([], :text),
                 synonyms: Sequel.pg_array([], :text),
                 colloquial_terms: Sequel.pg_array([], :text),
                 labels: { 'description' => 'No score label' })
        end

        get :index, params: { score_category: 'no_score' }, format: :json

        json = JSON.parse(response.body)
        scores = json['data'].map { |d| d.dig('attributes', 'description_score') }
        expect(scores).to all(be_nil)
      end
    end

    context 'with sorting' do
      it 'sorts by score descending' do
        get :index, params: { sort: 'score', direction: 'desc' }, format: :json

        json = JSON.parse(response.body)
        scores = json['data'].map { |d| d.dig('attributes', 'description_score') }
        expect(scores).to eq([0.9, 0.5])
      end

      it 'sorts by goods_nomenclature_item_id' do
        get :index, params: { sort: 'goods_nomenclature_item_id', direction: 'asc' }, format: :json

        expect(response).to have_http_status(:ok)
      end

      it 'ignores invalid sort columns' do
        get :index, params: { sort: 'invalid_column' }, format: :json

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with q param searching by commodity code prefix' do
      it 'returns labels matching the code prefix' do
        get :index, params: { q: commodity.goods_nomenclature_item_id[0..3] }, format: :json

        json = JSON.parse(response.body)
        item_ids = json['data'].map { |d| d.dig('attributes', 'goods_nomenclature_item_id') }
        expect(item_ids).to all(start_with(commodity.goods_nomenclature_item_id[0..3]))
      end
    end

    context 'with q param searching by text' do
      it 'matches description case-insensitively' do
        get :index, params: { q: 'horses' }, format: :json

        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
      end

      it 'matches known brands' do
        get :index, params: { q: 'Thoroughbred' }, format: :json

        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
      end

      it 'matches synonyms' do
        get :index, params: { q: 'bovine' }, format: :json

        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
      end

      it 'returns empty results for non-matching text' do
        get :index, params: { q: 'zznonexistentzz' }, format: :json

        json = JSON.parse(response.body)
        expect(json['data']).to be_empty
      end
    end

    context 'with q param too short' do
      it 'ignores single character non-numeric queries' do
        get :index, params: { q: 'a' }, format: :json

        json = JSON.parse(response.body)
        # Single char text is ignored, returns all results
        expect(json['data'].length).to eq(2)
      end
    end

    context 'with pagination' do
      it 'respects per_page parameter' do
        get :index, params: { per_page: 1 }, format: :json

        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
        expect(json.dig('meta', 'pagination', 'total_count')).to eq(2)
      end

      it 'respects page parameter' do
        get :index, params: { per_page: 1, page: 2 }, format: :json

        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
        expect(json.dig('meta', 'pagination', 'page')).to eq(2)
      end
    end

    context 'with nil scores' do
      let!(:nil_score) do # rubocop:disable RSpec/LetSetup
        create(:goods_nomenclature, producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX).tap do |gn|
          create(:goods_nomenclature_label,
                 goods_nomenclature: gn,
                 description: 'No score',
                 description_score: nil,
                 known_brands: Sequel.pg_array([], :text),
                 synonyms: Sequel.pg_array([], :text),
                 colloquial_terms: Sequel.pg_array([], :text),
                 labels: { 'description' => 'No score' })
        end
      end

      it 'places nil scores last when sorting ascending' do
        get :index, params: { sort: 'score', direction: 'asc' }, format: :json

        json = JSON.parse(response.body)
        scores = json['data'].map { |d| d.dig('attributes', 'description_score') }
        expect(scores.last).to be_nil
      end
    end
  end
end
