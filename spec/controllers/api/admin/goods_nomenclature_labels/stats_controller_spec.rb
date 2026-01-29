RSpec.describe Api::Admin::GoodsNomenclatureLabels::StatsController do
  routes { AdminApi.routes }

  describe '#show' do
    let(:pattern) do
      {
        data: {
          id: 'stats',
          type: 'goods_nomenclature_label_stats',
          attributes: {
            total_goods_nomenclatures: Integer,
            descriptions_count: Integer,
            known_brands_count: Integer,
            colloquial_terms_count: Integer,
            synonyms_count: Integer,
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
                 'known_brands' => %w[BrandA BrandB],
                 'colloquial_terms' => [],
                 'synonyms' => %w[syn1],
               }
      end

      it 'returns correct counts' do
        get :show, format: :json

        json = JSON.parse(response.body)
        attributes = json.dig('data', 'attributes')

        expect(attributes['total_goods_nomenclatures']).to eq(1)
        expect(attributes['descriptions_count']).to eq(1)
        expect(attributes['known_brands_count']).to eq(2)
        expect(attributes['colloquial_terms_count']).to eq(0)
        expect(attributes['synonyms_count']).to eq(1)
        expect(attributes['ai_created_only']).to eq(1)
        expect(attributes['human_edited']).to eq(0)
      end
    end
  end
end
