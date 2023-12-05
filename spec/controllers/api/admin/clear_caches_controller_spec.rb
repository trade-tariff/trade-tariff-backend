RSpec.describe Api::Admin::ClearCachesController do
  describe 'POST to #create' do
    before do
      login_as_api_user

      allow(ClearAllCachesWorker).to receive(:perform_async)

      post :create, params: { data: { type: :clear_cache, attributes: } }
    end

    context 'when apply is valid' do
      let(:attributes) { attributes_for :clear_cache }

      it { expect(response.status).to eq 201 }
      it { expect(ClearAllCachesWorker).to have_received(:perform_async) }
    end

    context 'when apply is not valid' do
      let(:attributes) { { foo: :bar } }

      let(:response_pattern) do
        {
          errors: Array,
        }.ignore_extra_keys!
      end

      it { expect(response.status).to eq 422 }
      it { expect(response.body).to match_json_expression response_pattern }
      it { expect(ClearAllCachesWorker).not_to have_received(:perform_async) }
    end
  end
end
