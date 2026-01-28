RSpec.describe Api::Admin::GoodsNomenclatureLabels::StatsController do
  routes { AdminApi.routes }

  describe '#show' do
    let(:pattern) do
      {
        data: {
          id: 'stats',
          type: 'goods_nomenclature_label_stats',
          attributes: {
            total_labels: Integer,
            with_description: Integer,
            with_known_brands: Integer,
            with_colloquial_terms: Integer,
            with_synonyms: Integer,
            ai_created_only: Integer,
            human_edited: Integer,
          },
        },
      }
    end

    it 'returns stats in JSONAPI format' do
      get :show, format: :json

      expect(response).to have_http_status(:ok)
      expect(response.body).to match_json_expression(pattern)
    end

    context 'when there are labels' do
      let(:commodity) { create :commodity }

      before do
        create :goods_nomenclature_label,
               goods_nomenclature: commodity,
               labels: {
                 'description' => 'Test description',
                 'known_brands' => %w[BrandA],
                 'colloquial_terms' => [],
                 'synonyms' => [],
               }
      end

      it 'returns correct counts' do
        get :show, format: :json

        json = JSON.parse(response.body)
        attributes = json.dig('data', 'attributes')

        expect(attributes['total_labels']).to eq(1)
        expect(attributes['with_description']).to eq(1)
        expect(attributes['with_known_brands']).to eq(1)
        expect(attributes['with_colloquial_terms']).to eq(0)
        expect(attributes['with_synonyms']).to eq(0)
        expect(attributes['ai_created_only']).to eq(1)
        expect(attributes['human_edited']).to eq(0)
      end
    end
  end
end
