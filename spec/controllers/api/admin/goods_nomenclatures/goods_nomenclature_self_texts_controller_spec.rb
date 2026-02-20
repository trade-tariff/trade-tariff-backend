RSpec.describe Api::Admin::GoodsNomenclatures::GoodsNomenclatureSelfTextsController do
  routes { AdminApi.routes }

  describe '#show' do
    let(:pattern) do
      {
        data: {
          id: String,
          type: 'goods_nomenclature_self_text',
          attributes: {
            goods_nomenclature_sid: Integer,
            goods_nomenclature_item_id: String,
            self_text: String,
            generation_type: String,
            needs_review: wildcard_matcher,
            manually_edited: wildcard_matcher,
            stale: wildcard_matcher,
            generated_at: String,
            eu_self_text: wildcard_matcher,
            similarity_score: wildcard_matcher,
            coherence_score: wildcard_matcher,
            input_context: Hash,
            nomenclature_type: wildcard_matcher,
            score: wildcard_matcher,
          },
        },
      }
    end

    context 'when self text record exists' do
      let!(:self_text) { create :goods_nomenclature_self_text }

      it 'returns rendered record' do
        get :show, params: { goods_nomenclature_id: self_text.goods_nomenclature_item_id }, format: :json

        expect(response).to have_http_status(:ok)
        expect(response.body).to match_json_expression pattern
      end
    end

    context 'when self text record does not exist' do
      it 'returns not found' do
        get :show, params: { goods_nomenclature_id: '9999999999' }, format: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe '#show input_context enrichment' do
    let(:parent_sid) { 12_345 }
    let!(:parent_self_text) do # rubocop:disable RSpec/LetSetup
      create(:goods_nomenclature_self_text,
             goods_nomenclature_sid: parent_sid,
             self_text: 'Live animals >> Other live animals',
             generation_type: 'ai')
    end

    let!(:self_text) do
      create(:goods_nomenclature_self_text,
             input_context: {
               'ancestors' => [
                 { 'sid' => parent_sid, 'description' => 'Other' },
               ],
               'description' => 'Widgets',
             })
    end

    it 'enriches ancestors with current self_texts' do
      get :show, params: { goods_nomenclature_id: self_text.goods_nomenclature_item_id }, format: :json

      json = JSON.parse(response.body)
      ancestors = json.dig('data', 'attributes', 'input_context', 'ancestors')

      expect(ancestors.first['self_text']).to eq('Live animals >> Other live animals')
    end
  end

  describe '#update' do
    let!(:self_text) { create :goods_nomenclature_self_text }

    context 'when save succeeds' do
      let(:new_text) { 'Updated self text content' }

      it 'responds with success' do
        put :update, params: {
          goods_nomenclature_id: self_text.goods_nomenclature_item_id,
          data: { type: 'goods_nomenclature_self_text', attributes: { self_text: new_text } },
        }, format: :json

        expect(response).to have_http_status(:ok)
      end

      it 'updates the self text' do
        put :update, params: {
          goods_nomenclature_id: self_text.goods_nomenclature_item_id,
          data: { type: 'goods_nomenclature_self_text', attributes: { self_text: new_text } },
        }, format: :json

        json = JSON.parse(response.body)
        expect(json.dig('data', 'attributes', 'self_text')).to eq(new_text)
      end

      it 'sets manually_edited to true' do
        put :update, params: {
          goods_nomenclature_id: self_text.goods_nomenclature_item_id,
          data: { type: 'goods_nomenclature_self_text', attributes: { self_text: new_text } },
        }, format: :json

        json = JSON.parse(response.body)
        expect(json.dig('data', 'attributes', 'manually_edited')).to be true
      end

      it 'clears needs_review flag' do
        self_text.update(needs_review: true)

        put :update, params: {
          goods_nomenclature_id: self_text.goods_nomenclature_item_id,
          data: { type: 'goods_nomenclature_self_text', attributes: { self_text: new_text } },
        }, format: :json

        json = JSON.parse(response.body)
        expect(json.dig('data', 'attributes', 'needs_review')).to be false
      end
    end

    context 'when self text record does not exist' do
      it 'returns 404' do
        put :update, params: {
          goods_nomenclature_id: '9999999999',
          data: { type: 'goods_nomenclature_self_text', attributes: { self_text: 'test' } },
        }, format: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe '#score' do
    let!(:self_text) { create :goods_nomenclature_self_text }
    let(:scorer) { instance_double(SelfTextConfidenceScorer, score: nil) }

    before do
      allow(SelfTextConfidenceScorer).to receive(:new).and_return(scorer)
    end

    it 'triggers scoring and returns success' do
      post :score, params: { goods_nomenclature_id: self_text.goods_nomenclature_item_id }, format: :json

      expect(response).to have_http_status(:ok)
      expect(scorer).to have_received(:score).with([self_text.goods_nomenclature_sid])
    end

    context 'when self text record does not exist' do
      it 'returns 404' do
        post :score, params: { goods_nomenclature_id: '9999999999' }, format: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe '#approve' do
    let!(:self_text) { create :goods_nomenclature_self_text, needs_review: true, manually_edited: false }

    it 'clears needs_review' do
      post :approve, params: { goods_nomenclature_id: self_text.goods_nomenclature_item_id }, format: :json

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json.dig('data', 'attributes', 'needs_review')).to be false
    end

    it 'does not set manually_edited' do
      post :approve, params: { goods_nomenclature_id: self_text.goods_nomenclature_item_id }, format: :json

      json = JSON.parse(response.body)
      expect(json.dig('data', 'attributes', 'manually_edited')).to be false
    end

    context 'when self text record does not exist' do
      it 'returns 404' do
        post :approve, params: { goods_nomenclature_id: '9999999999' }, format: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe '#reject' do
    let!(:self_text) { create :goods_nomenclature_self_text, needs_review: false }

    it 'sets needs_review to true' do
      post :reject, params: { goods_nomenclature_id: self_text.goods_nomenclature_item_id }, format: :json

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json.dig('data', 'attributes', 'needs_review')).to be true
    end

    context 'when self text record does not exist' do
      it 'returns 404' do
        post :reject, params: { goods_nomenclature_id: '9999999999' }, format: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe '#regenerate' do
    let!(:goods_nomenclature) do
      create(:goods_nomenclature,
             :actual,
             goods_nomenclature_item_id: '0101210000',
             producline_suffix: '80')
    end
    let!(:chapter) do # rubocop:disable RSpec/LetSetup
      create(:chapter,
             :actual,
             goods_nomenclature_item_id: '0100000000')
    end
    let!(:self_text) do
      create(:goods_nomenclature_self_text,
             goods_nomenclature: goods_nomenclature,
             context_hash: 'old_hash',
             stale: false)
    end

    before do
      allow(GenerateSelfText::AiBuilder).to receive(:call)
    end

    it 'invalidates context_hash, marks stale, and calls the builder' do
      post :regenerate, params: { goods_nomenclature_id: self_text.goods_nomenclature_item_id }, format: :json

      expect(response).to have_http_status(:ok)
      expect(self_text.reload.context_hash).to eq('invalidated')
      expect(self_text.reload.stale).to be true
      expect(GenerateSelfText::AiBuilder).to have_received(:call)
    end

    context 'when self text record does not exist' do
      it 'returns 404' do
        post :regenerate, params: { goods_nomenclature_id: '9999999999' }, format: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
