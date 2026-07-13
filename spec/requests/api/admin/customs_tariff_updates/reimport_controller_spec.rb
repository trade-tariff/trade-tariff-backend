RSpec.describe Api::Admin::CustomsTariffUpdates::ReimportController do
  describe 'POST #create' do
    let!(:update) { create(:customs_tariff_update) }

    before do
      allow(CustomsTariffReimportWorker).to receive(:perform_async)
      allow(XiCnReimportWorker).to receive(:perform_async)
    end

    context 'when SERVICE is uk' do
      before { allow(TradeTariffBackend).to receive(:xi?).and_return(false) }

      it 'returns 202 and enqueues CustomsTariffReimportWorker' do
        post "/uk/admin/customs_tariff_updates/#{update.version}/reimport.json",
             headers: request_headers(format: :json)

        expect(response.status).to eq(202)
        expect(CustomsTariffReimportWorker).to have_received(:perform_async).with(update.version)
        expect(XiCnReimportWorker).not_to have_received(:perform_async)
      end
    end

    context 'when SERVICE is xi' do
      before { allow(TradeTariffBackend).to receive(:xi?).and_return(true) }

      it 'returns 202 and enqueues XiCnReimportWorker' do
        post "/uk/admin/customs_tariff_updates/#{update.version}/reimport.json",
             headers: request_headers(format: :json)

        expect(response.status).to eq(202)
        expect(XiCnReimportWorker).to have_received(:perform_async).with(update.version)
        expect(CustomsTariffReimportWorker).not_to have_received(:perform_async)
      end
    end

    it 'returns 404 for an unknown version' do
      post '/uk/admin/customs_tariff_updates/nonexistent.99/reimport.json',
           headers: request_headers(format: :json)

      expect(response.status).to eq(404)
      expect(CustomsTariffReimportWorker).not_to have_received(:perform_async)
    end
  end
end
