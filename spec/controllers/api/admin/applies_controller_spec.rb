RSpec.describe Api::Admin::AppliesController do
  routes { AdminApi.routes }

  describe 'POST to #create' do
    before do
      allow(ApplyWorker).to receive(:perform_async)

      post :create, params: { data: { type: :apply, attributes: apply_attributes } }
    end

    context 'when apply is valid' do
      let(:apply_attributes) { attributes_for :apply }

      it { expect(response.status).to eq 201 }
      it { expect(ApplyWorker).to have_received(:perform_async) }
    end

    context 'when apply is not valid' do
      let(:apply_attributes) { { data: { type: :apply, attributes: {} } } }

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
