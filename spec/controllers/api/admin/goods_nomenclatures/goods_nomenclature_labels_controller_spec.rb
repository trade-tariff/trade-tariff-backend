RSpec.describe Api::Admin::GoodsNomenclatures::GoodsNomenclatureLabelsController do
  routes { AdminApi.routes }

  describe '#show' do
    let(:pattern) do
      {
        data: {
          id: String,
          type: 'goods_nomenclature_label',
          attributes: {
            goods_nomenclature_sid: Integer,
            goods_nomenclature_item_id: String,
            goods_nomenclature_type: String,
            producline_suffix: String,
            stale: wildcard_matcher,
            manually_edited: wildcard_matcher,
            context_hash: wildcard_matcher,
            labels: Hash,
          },
        },
      }
    end

    context 'when goods nomenclature label is present' do
      let(:commodity) { create :commodity }

      before { create :goods_nomenclature_label, goods_nomenclature: commodity }

      it 'returns rendered record' do
        get :show, params: { goods_nomenclature_id: commodity.goods_nomenclature_item_id }, format: :json

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'when goods nomenclature label is not present' do
      let(:commodity) { create :commodity }

      it 'returns not found if record was not found' do
        get :show, params: { goods_nomenclature_id: commodity.goods_nomenclature_item_id }, format: :json

        expect(response.status).to eq 404
      end
    end

    context 'when goods nomenclature does not exist' do
      it 'returns not found' do
        get :show, params: { goods_nomenclature_id: '9999999999' }, format: :json

        expect(response.status).to eq 404
      end
    end
  end

  describe '#update' do
    let(:commodity) { create :commodity }

    before { create :goods_nomenclature_label, goods_nomenclature: commodity }

    context 'when save succeeded' do
      let(:new_labels) do
        {
          description: 'Updated description',
          known_brands: %w[Brand1 Brand2],
          colloquial_terms: ['common term'],
          synonyms: %w[synonym1 synonym2],
        }
      end

      it 'responds with success' do
        put :update, params: {
          goods_nomenclature_id: commodity.goods_nomenclature_item_id,
          data: { type: 'goods_nomenclature_label', attributes: { labels: new_labels } },
        }, format: :json

        expect(response.status).to eq 200
      end

      it 'updates the label in place' do
        put :update, params: {
          goods_nomenclature_id: commodity.goods_nomenclature_item_id,
          data: { type: 'goods_nomenclature_label', attributes: { labels: new_labels } },
        }, format: :json

        label = GoodsNomenclatureLabel
          .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid)
          .first

        expect(label.labels['description']).to eq 'Updated description'
      end

      it 'marks the label as manually edited' do
        put :update, params: {
          goods_nomenclature_id: commodity.goods_nomenclature_item_id,
          data: { type: 'goods_nomenclature_label', attributes: { labels: new_labels } },
        }, format: :json

        label = GoodsNomenclatureLabel
          .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid)
          .first

        expect(label.manually_edited).to be true
      end
    end

    context 'when updating label suggestions' do
      let(:new_labels) do
        {
          description: 'Updated description',
          known_brands: [],
          colloquial_terms: [],
          synonyms: %w[synonym1 synonym2],
        }
      end

      it 'creates search suggestions for label terms' do
        expect {
          put :update, params: {
            goods_nomenclature_id: commodity.goods_nomenclature_item_id,
            data: { type: 'goods_nomenclature_label', attributes: { labels: new_labels } },
          }, format: :json
        }.to change {
          SearchSuggestion
            .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid)
            .where(type: LabelSuggestionsUpdaterService::LABEL_TYPES)
            .count
        }.by(2)
      end

      it 'removes old label suggestions when terms are deleted' do
        # First update: add synonyms
        put :update, params: {
          goods_nomenclature_id: commodity.goods_nomenclature_item_id,
          data: { type: 'goods_nomenclature_label', attributes: { labels: new_labels } },
        }, format: :json

        expect(
          SearchSuggestion
            .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid, type: 'synonym')
            .count,
        ).to eq(2)

        # Second update: remove all synonyms
        empty_labels = { description: 'Updated again', known_brands: [], colloquial_terms: [], synonyms: [] }

        put :update, params: {
          goods_nomenclature_id: commodity.goods_nomenclature_item_id,
          data: { type: 'goods_nomenclature_label', attributes: { labels: empty_labels } },
        }, format: :json

        expect(
          SearchSuggestion
            .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid, type: 'synonym')
            .count,
        ).to eq(0)
      end
    end

    context 'when goods nomenclature does not exist' do
      it 'returns 404' do
        put :update, params: {
          goods_nomenclature_id: '9999999999',
          data: { type: 'goods_nomenclature_label', attributes: { labels: { description: 'test' } } },
        }, format: :json

        expect(response.status).to eq 404
      end
    end

    context 'when goods nomenclature label does not exist' do
      let(:commodity_without_label) { create :commodity }

      it 'returns 404' do
        put :update, params: {
          goods_nomenclature_id: commodity_without_label.goods_nomenclature_item_id,
          data: { type: 'goods_nomenclature_label', attributes: { labels: { description: 'test' } } },
        }, format: :json

        expect(response.status).to eq 404
      end
    end
  end
end
