RSpec.describe Api::Admin::CustomsTariffUpdates::StatusController do
  describe 'PATCH #update' do
    let!(:update) { create(:customs_tariff_update) }

    it 'changes status to approved' do
      patch "/uk/admin/customs_tariff_updates/#{update.version}/status.json",
            params: { data: { attributes: { status: 'approved' } } },
            headers: request_headers(format: :json), as: :json

      expect(response.status).to eq(200)
      expect(update.reload.status).to eq('approved')
    end

    it 'returns 422 when status is already the same' do
      patch "/uk/admin/customs_tariff_updates/#{update.version}/status.json",
            params: { data: { attributes: { status: 'pending' } } },
            headers: request_headers(format: :json), as: :json

      expect(response.status).to eq(422)
    end

    it 'returns 422 for an invalid status value' do
      patch "/uk/admin/customs_tariff_updates/#{update.version}/status.json",
            params: { data: { attributes: { status: 'bogus' } } },
            headers: request_headers(format: :json), as: :json

      expect(response.status).to eq(422)
    end

    it 'allows changing the status of any update, not just the latest' do
      older = create(:customs_tariff_update, :approved, validity_start_date: 1.month.ago)

      patch "/uk/admin/customs_tariff_updates/#{older.version}/status.json",
            params: { data: { attributes: { status: 'rejected' } } },
            headers: request_headers(format: :json), as: :json

      expect(response.status).to eq(200)
      expect(older.reload.status).to eq('rejected')
    end
  end
end
