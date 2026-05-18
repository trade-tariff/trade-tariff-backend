RSpec.describe Api::Admin::AppliesController do
  describe 'POST to #create' do
    before do
      allow(ApplyWorker).to receive(:perform_async)
    end

    context 'when apply is valid' do
      before do
        post '/uk/admin/applies', headers: request_headers({ 'X-Whodunnit' => 'test-user-uid' }), as: :json
      end

      it { expect(response.status).to eq 201 }
      it { expect(ApplyWorker).to have_received(:perform_async) }
    end

    context 'when apply is not valid' do
      before do
        post '/uk/admin/applies', headers: request_headers, as: :json
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
