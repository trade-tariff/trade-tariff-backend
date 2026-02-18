RSpec.describe Api::Admin::GoodsNomenclatureSelfTextsController do
  routes { AdminApi.routes }

  describe '#index' do
    let!(:commodity) do
      create(:goods_nomenclature, producline_suffix: '80').tap do |gn|
        create(:goods_nomenclature_self_text,
               goods_nomenclature: gn,
               similarity_score: 0.5,
               coherence_score: 0.6,
               generation_type: 'ai',
               needs_review: true,
               stale: false,
               manually_edited: false)
      end
    end

    let!(:subheading) do # rubocop:disable RSpec/LetSetup
      create(:goods_nomenclature, producline_suffix: '10').tap do |gn|
        create(:goods_nomenclature_self_text,
               goods_nomenclature: gn,
               similarity_score: 0.9,
               coherence_score: 0.95,
               generation_type: 'ai',
               needs_review: false,
               stale: true,
               manually_edited: false)
      end
    end

    let!(:mechanical) do
      create(:goods_nomenclature, producline_suffix: '80').tap do |gn|
        create(:goods_nomenclature_self_text,
               goods_nomenclature: gn,
               similarity_score: 0.7,
               coherence_score: 0.7,
               generation_type: 'mechanical')
      end
    end

    it 'returns only AI-generated self texts' do
      get :index, format: :json

      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(2)

      types = json['data'].map { |d| d.dig('attributes', 'generation_type') }
      expect(types).to all(eq('ai'))
    end

    it 'excludes mechanical self texts' do
      get :index, format: :json

      json = JSON.parse(response.body)
      sids = json['data'].map { |d| d.dig('attributes', 'goods_nomenclature_sid') }
      expect(sids).not_to include(mechanical.goods_nomenclature_sid)
    end

    it 'includes combined score attribute' do
      get :index, format: :json

      json = JSON.parse(response.body)
      scores = json['data'].map { |d| d.dig('attributes', 'score') }
      expect(scores).to contain_exactly(0.55, 0.925)
    end

    it 'sorts by combined score ascending by default' do
      get :index, format: :json

      json = JSON.parse(response.body)
      scores = json['data'].map { |d| d.dig('attributes', 'score') }
      expect(scores).to eq([0.55, 0.925])
    end

    it 'includes pagination meta' do
      get :index, format: :json

      json = JSON.parse(response.body)
      pagination = json.dig('meta', 'pagination')
      expect(pagination['page']).to eq(1)
      expect(pagination['total_count']).to eq(2)
    end

    it 'includes nomenclature_type attribute' do
      get :index, format: :json

      json = JSON.parse(response.body)
      types = json['data'].map { |d| d.dig('attributes', 'nomenclature_type') }
      expect(types).to contain_exactly('commodity', 'subheading')
    end

    context 'with type filter' do
      it 'filters to commodities only' do
        get :index, params: { type: 'commodity' }, format: :json

        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
        expect(json['data'].first.dig('attributes', 'nomenclature_type')).to eq('commodity')
      end

      it 'filters to subheadings only' do
        get :index, params: { type: 'subheading' }, format: :json

        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
        expect(json['data'].first.dig('attributes', 'nomenclature_type')).to eq('subheading')
      end
    end

    context 'with status filter' do
      it 'filters to needs_review' do
        get :index, params: { status: 'needs_review' }, format: :json

        json = JSON.parse(response.body)
        expect(json['data'].length).to eq(1)
        expect(json['data'].first.dig('attributes', 'needs_review')).to be true
      end

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

    context 'with score_category filter' do
      let!(:low_score) do # rubocop:disable RSpec/LetSetup
        create(:goods_nomenclature, producline_suffix: '80').tap do |gn|
          create(:goods_nomenclature_self_text,
                 goods_nomenclature: gn,
                 similarity_score: 0.2,
                 coherence_score: nil,
                 generation_type: 'ai')
        end
      end

      it 'filters to bad scores (below 0.3)' do
        get :index, params: { score_category: 'bad' }, format: :json

        json = JSON.parse(response.body)
        scores = json['data'].map { |d| d.dig('attributes', 'score') }
        expect(scores).to all(be < 0.3)
      end

      it 'filters to okay scores (0.3 to 0.5)' do
        get :index, params: { score_category: 'okay' }, format: :json

        json = JSON.parse(response.body)
        scores = json['data'].map { |d| d.dig('attributes', 'score') }
        expect(scores).to all(be >= 0.3)
        expect(scores).to all(be < 0.5)
      end

      it 'filters to good scores (0.5 to 0.85)' do
        get :index, params: { score_category: 'good' }, format: :json

        json = JSON.parse(response.body)
        scores = json['data'].map { |d| d.dig('attributes', 'score') }
        expect(scores).to all(be >= 0.5)
        expect(scores).to all(be < 0.85)
      end

      it 'filters to amazing scores (0.85+)' do
        get :index, params: { score_category: 'amazing' }, format: :json

        json = JSON.parse(response.body)
        scores = json['data'].map { |d| d.dig('attributes', 'score') }
        expect(scores).to all(be >= 0.85)
      end

      it 'filters to records with no score' do
        create(:goods_nomenclature, producline_suffix: '80').tap do |gn|
          create(:goods_nomenclature_self_text,
                 goods_nomenclature: gn,
                 similarity_score: nil,
                 coherence_score: nil,
                 generation_type: 'ai')
        end

        get :index, params: { score_category: 'no_score' }, format: :json

        json = JSON.parse(response.body)
        scores = json['data'].map { |d| d.dig('attributes', 'score') }
        expect(scores).to all(be_nil)
      end
    end

    context 'with sorting' do
      it 'sorts by score descending' do
        get :index, params: { sort: 'score', direction: 'desc' }, format: :json

        json = JSON.parse(response.body)
        scores = json['data'].map { |d| d.dig('attributes', 'score') }
        expect(scores).to eq([0.925, 0.55])
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

    context 'with q param searching by commodity code prefix' do
      it 'returns self texts matching the code prefix' do
        get :index, params: { q: commodity.goods_nomenclature_item_id[0..3] }, format: :json

        json = JSON.parse(response.body)
        item_ids = json['data'].map { |d| d.dig('attributes', 'goods_nomenclature_item_id') }
        expect(item_ids).to all(start_with(commodity.goods_nomenclature_item_id[0..3]))
      end
    end

    context 'with q param searching by text' do
      it 'matches self_text content case-insensitively' do
        get :index, params: { q: 'widgets' }, format: :json

        json = JSON.parse(response.body)
        expect(json['data']).not_to be_empty
        texts = json['data'].map { |d| d.dig('attributes', 'self_text') }
        expect(texts).to all(match(/widget/i))
      end

      it 'matches input_context content' do
        get :index, params: { q: 'Widgets' }, format: :json

        json = JSON.parse(response.body)
        expect(json['data']).not_to be_empty
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

    context 'with nil scores' do
      let!(:nil_scores) do # rubocop:disable RSpec/LetSetup
        create(:goods_nomenclature, producline_suffix: '80').tap do |gn|
          create(:goods_nomenclature_self_text,
                 goods_nomenclature: gn,
                 similarity_score: nil,
                 coherence_score: nil,
                 generation_type: 'ai')
        end
      end

      it 'places nil scores last when sorting ascending' do
        get :index, params: { sort: 'score', direction: 'asc' }, format: :json

        json = JSON.parse(response.body)
        scores = json['data'].map { |d| d.dig('attributes', 'score') }
        expect(scores.last).to be_nil
      end
    end
  end
end
