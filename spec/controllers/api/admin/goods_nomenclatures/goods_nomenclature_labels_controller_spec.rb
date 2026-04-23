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
            needs_review: wildcard_matcher,
            approved: wildcard_matcher,
            stale: wildcard_matcher,
            manually_edited: wildcard_matcher,
            expired: wildcard_matcher,
            created_at: String,
            updated_at: String,
            context_hash: wildcard_matcher,
            labels: Hash,
            description: wildcard_matcher,
            original_description: wildcard_matcher,
            synonyms: wildcard_matcher,
            colloquial_terms: wildcard_matcher,
            known_brands: wildcard_matcher,
            description_score: wildcard_matcher,
            synonym_scores: wildcard_matcher,
            colloquial_term_scores: wildcard_matcher,
            score: wildcard_matcher,
            has_self_text: wildcard_matcher,
          },
        },
        meta: {
          version: {
            current: wildcard_matcher,
            oid: wildcard_matcher,
            previous_oid: wildcard_matcher,
            has_previous_version: wildcard_matcher,
            latest_event: wildcard_matcher,
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

      it 'marks the edited label as approved and clears review' do
        GoodsNomenclatureLabel
          .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid)
          .first
          .update(needs_review: true, approved: false)

        put :update, params: {
          goods_nomenclature_id: commodity.goods_nomenclature_item_id,
          data: { type: 'goods_nomenclature_label', attributes: { labels: new_labels } },
        }, format: :json

        label = GoodsNomenclatureLabel
          .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid)
          .first

        expect(label).to have_attributes(
          needs_review: false,
          approved: true,
        )
      end

      it 'enqueues ScoreLabelBatchWorker' do
        allow(ScoreLabelBatchWorker).to receive(:perform_async)

        put :update, params: {
          goods_nomenclature_id: commodity.goods_nomenclature_item_id,
          data: { type: 'goods_nomenclature_label', attributes: { labels: new_labels } },
        }, format: :json

        expect(ScoreLabelBatchWorker).to have_received(:perform_async).with(commodity.goods_nomenclature_sid)
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

    context 'when save fails' do
      it 'returns 422 without reindexing or enqueueing scoring' do
        label = GoodsNomenclatureLabel
          .where(goods_nomenclature_sid: commodity.goods_nomenclature_sid)
          .first

        allow(controller).to receive(:goods_nomenclature_label).and_return(label)
        allow(label)
          .to receive(:save)
          .with(raise_on_failure: false)
          .and_return(false)
        allow(TradeTariffBackend.search_client).to receive(:index)
        allow(ScoreLabelBatchWorker).to receive(:perform_async)

        put :update, params: {
          goods_nomenclature_id: commodity.goods_nomenclature_item_id,
          data: {
            type: 'goods_nomenclature_label',
            attributes: { labels: { description: 'test' } },
          },
        }, format: :json

        expect(response.status).to eq 422
        expect(TradeTariffBackend.search_client).not_to have_received(:index)
        expect(ScoreLabelBatchWorker).not_to have_received(:perform_async)
      end
    end
  end

  describe '#show with version browsing' do
    let(:commodity) { create :commodity }
    let!(:label) { create :goods_nomenclature_label, goods_nomenclature: commodity, description: 'original' }

    it 'includes version meta in the response' do
      get :show, params: { goods_nomenclature_id: commodity.goods_nomenclature_item_id }, format: :json

      json = JSON.parse(response.body)
      version_meta = json.dig('meta', 'version')

      expect(version_meta['current']).to be true
      expect(version_meta['oid']).to be_present
    end

    context 'when viewing a historical version via filter[oid]' do
      before { label.update(description: 'changed') }

      it 'returns the historical version data' do
        version = label.versions.order(:id).first

        get :show, params: {
          goods_nomenclature_id: commodity.goods_nomenclature_item_id,
          filter: { oid: version.id },
        }, format: :json

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json.dig('data', 'attributes', 'description')).to eq('original')
        expect(json.dig('meta', 'version', 'current')).to be false
      end
    end

    context 'when viewing the latest version via filter[oid]' do
      before { label.update(description: 'changed') }

      it 'returns current=true' do
        version = label.versions.order(Sequel.desc(:id)).first

        get :show, params: {
          goods_nomenclature_id: commodity.goods_nomenclature_item_id,
          filter: { oid: version.id },
        }, format: :json

        json = JSON.parse(response.body)
        expect(json.dig('meta', 'version', 'current')).to be true
      end
    end

    context 'when version does not exist' do
      it 'returns 404' do
        get :show, params: {
          goods_nomenclature_id: commodity.goods_nomenclature_item_id,
          filter: { oid: 999_999 },
        }, format: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe '#versions' do
    let(:commodity) { create :commodity }
    let!(:label) { create :goods_nomenclature_label, goods_nomenclature: commodity }

    it 'returns versions for the label' do
      label.update(description: 'changed')

      get :versions, params: { goods_nomenclature_id: commodity.goods_nomenclature_item_id }, format: :json

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['data']).to be_present
      expect(json['data'].first['type']).to eq('version')
    end

    context 'when label does not exist' do
      it 'returns 404' do
        get :versions, params: { goods_nomenclature_id: '9999999999' }, format: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe '#approve' do
    let(:commodity) { create :commodity }
    let!(:label) { create :goods_nomenclature_label, goods_nomenclature: commodity, needs_review: true, approved: false }

    it 'approves the label and clears review' do
      post :approve, params: { goods_nomenclature_id: commodity.goods_nomenclature_item_id }, format: :json

      expect(response).to have_http_status(:ok)
      expect(label.reload).to have_attributes(
        needs_review: false,
        approved: true,
      )
    end
  end

  describe '#reject' do
    let(:commodity) { create :commodity }
    let!(:label) { create :goods_nomenclature_label, goods_nomenclature: commodity, needs_review: false, approved: true }

    it 'marks the label for review and clears approval' do
      post :reject, params: { goods_nomenclature_id: commodity.goods_nomenclature_item_id }, format: :json

      expect(response).to have_http_status(:ok)
      expect(label.reload).to have_attributes(
        needs_review: true,
        approved: false,
      )
    end
  end

  describe '#score' do
    let(:commodity) { create :commodity }
    let!(:label) { create :goods_nomenclature_label, goods_nomenclature: commodity, needs_review: true, approved: true }
    let(:scorer) { instance_double(LabelConfidenceScorer, score: nil) }

    before do
      allow(LabelConfidenceScorer).to receive(:new).and_return(scorer)
    end

    it 'scores the label without changing review state' do
      post :score, params: { goods_nomenclature_id: commodity.goods_nomenclature_item_id }, format: :json

      expect(response).to have_http_status(:ok)
      expect(scorer).to have_received(:score).with([label.goods_nomenclature_sid])
      expect(label.reload).to have_attributes(
        needs_review: true,
        approved: true,
      )
    end
  end

  describe '#regenerate' do
    let(:commodity) { create :commodity }
    let!(:label) do
      create(:goods_nomenclature_label,
             :stale,
             goods_nomenclature: commodity,
             needs_review: true,
             approved: true,
             manually_edited: true,
             description: 'Operator label')
    end
    let(:generated_label) do
      build(:goods_nomenclature_label,
            goods_nomenclature: commodity,
            labels: { 'description' => 'Generated label' },
            description: 'Generated label',
            synonyms: Sequel.pg_array(['generated synonym'], :text),
            context_hash: 'fresh-hash')
    end

    before do
      allow(LabelService).to receive(:call).and_return([generated_label])
      allow(TradeTariffBackend.search_client).to receive(:index)
      allow(LabelSuggestionsUpdaterService).to receive(:new).and_return(instance_double(LabelSuggestionsUpdaterService, call: nil))
      allow(ScoreLabelBatchWorker).to receive(:perform_async)
    end

    it 'replaces the label and clears lifecycle review tags' do
      post :regenerate, params: { goods_nomenclature_id: commodity.goods_nomenclature_item_id }, format: :json

      expect(response).to have_http_status(:ok)
      expect(LabelService).to have_received(:call).with([
        have_attributes(goods_nomenclature_sid: commodity.goods_nomenclature_sid),
      ])
      expect(label.reload).to have_attributes(
        description: 'Generated label',
        context_hash: 'fresh-hash',
        stale: false,
        needs_review: false,
        approved: false,
        manually_edited: false,
      )
      expect(label.synonyms.to_a).to eq(['generated synonym'])
    end

    it 'enqueues label scoring' do
      post :regenerate, params: { goods_nomenclature_id: commodity.goods_nomenclature_item_id }, format: :json

      expect(ScoreLabelBatchWorker).to have_received(:perform_async).with(label.goods_nomenclature_sid)
    end
  end
end
