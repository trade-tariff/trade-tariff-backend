RSpec.describe Api::Admin::CdsUpdateNotificationsController do
  routes { AdminApi.routes }

  describe 'POST to #create' do
    let(:cds_attributes) { attributes_for :cds_update_notification }

    context 'when cds_update_notification is valid' do
      it 'responds with success + redirect', :aggregate_failures do
        expect {
          post :create, params: { data: { type: :cds_update_notification, attributes: cds_attributes } }
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
        post :create, params: { data: { type: :cds_update_notification, attributes: { name: nil } } }

        expect(response.status).to eq 422
        expect(response.body).to match_json_expression response_pattern
      end
    end
  end
end
