RSpec.describe Api::Admin::DownloadsController do
  describe 'POST to #create' do
    before do
      allow(DownloadWorker).to receive(:perform_async)
    end

    context 'when download is valid' do
      before do
        post '/uk/admin/downloads', headers: request_headers({ 'X-Whodunnit' => 'test-user-uid' }), as: :json
      end

      it { expect(response.status).to eq 201 }
      it { expect(DownloadWorker).to have_received(:perform_async) }
    end

    context 'when download is not valid' do
      before do
        post '/uk/admin/downloads', headers: request_headers, as: :json
      end

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
