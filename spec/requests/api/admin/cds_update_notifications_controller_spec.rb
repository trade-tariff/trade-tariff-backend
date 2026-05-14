RSpec.describe Api::Admin::CdsUpdateNotificationsController, :admin do
  describe 'POST to #create' do
    context 'when cds_update_notification is valid' do
      let(:cds_update) { create(:cds_update) }

      it 'responds with success + redirect', :aggregate_failures do
        expect {
          post '/uk/admin/cds_update_notifications', params: { data: { type: :cds_update_notification, attributes: { filename: cds_update.filename } } }, headers: request_headers({ 'X-Whodunnit' => 'test-user-uid' }), as: :json
        }.to change(CdsUpdateNotification, :count).by(1)
        expect(response.status).to eq 201
        expect(response.location).to eq api_cds_update_notifications_url
      end
    end

    context 'when cds_update_notification is not valid' do
      let(:response_pattern) do
        {
          errors: Array,
        }.ignore_extra_keys!
      end

      it 'returns errors for cds_update_notification', :aggregate_failures do
        post '/uk/admin/cds_update_notifications', params: { data: { type: :cds_update_notification, attributes: { name: nil } } }, headers: request_headers, as: :json

        expect(response.status).to eq 422
        expect(response.body).to match_json_expression response_pattern
      end
    end
  end
end
