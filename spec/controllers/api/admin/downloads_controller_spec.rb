RSpec.describe Api::Admin::DownloadsController do
  routes { AdminApi.routes }

  describe 'POST to #create' do
    before do
      login_as_api_user

      allow(DownloadWorker).to receive(:perform_async)

      post :create, params: { data: { type: :download, attributes: download_attributes } }
    end

    context 'when apply is valid' do
      let(:download_attributes) { attributes_for :download }

      it { expect(response.status).to eq 201 }
      it { expect(DownloadWorker).to have_received(:perform_async) }
    end

    context 'when apply is not valid' do
      let(:download_attributes) { { data: { type: :download, attributes: {} } } }

      let(:response_pattern) do
        {
          errors: Array,
        }.ignore_extra_keys!
      end

      it { expect(response.status).to eq 422 }
      it { expect(response.body).to match_json_expression response_pattern }
      it { expect(DownloadWorker).not_to have_received(:perform_async) }
    end
  end
end
