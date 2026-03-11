RSpec.describe Api::Admin::AppliesController do
  routes { AdminApi.routes }

  describe 'POST to #create' do
    before do
      allow(ApplyWorker).to receive(:perform_async)
    end

    context 'when apply is valid' do
      before do
        request.headers['X-Whodunnit'] = 'test-user-uid'
        post :create
      end

      it { expect(response.status).to eq 201 }
      it { expect(ApplyWorker).to have_received(:perform_async) }
    end

    context 'when apply is not valid' do
      before do
        post :create
      end

      let(:response_pattern) do
        {
          errors: Array,
        }.ignore_extra_keys!
      end

      it { expect(response.status).to eq 422 }
      it { expect(response.body).to match_json_expression response_pattern }
      it { expect(ApplyWorker).not_to have_received(:perform_async) }
    end
  end
end
