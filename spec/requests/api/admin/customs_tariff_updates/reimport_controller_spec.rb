RSpec.describe Api::Admin::CustomsTariffUpdates::ReimportController do
  describe 'POST #create' do
    let!(:update) { create(:customs_tariff_update) }

    before do
      allow(CustomsTariffReimportWorker).to receive(:perform_async)
    end

    it 'returns 202 and enqueues the worker' do
      post "/uk/admin/customs_tariff_updates/#{update.version}/reimport.json",
           headers: request_headers(format: :json)

      expect(response.status).to eq(202)
      expect(CustomsTariffReimportWorker).to have_received(:perform_async).with(update.version)
    end

    it 'returns 404 for an unknown version' do
      post '/uk/admin/customs_tariff_updates/nonexistent.99/reimport.json',
           headers: request_headers(format: :json)

      expect(response.status).to eq(404)
      expect(CustomsTariffReimportWorker).not_to have_received(:perform_async)
    end
  end
end
