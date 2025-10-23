RSpec.describe Api::V2::NotificationsController, :v2 do
  subject(:do_request) { make_request && response }

  describe 'POST #create' do
    subject(:do_request) { post api_notifications_path, params: params, headers: headers, as: :json }

    let(:make_request) { post :create, params: params, headers: headers }

    let(:params) do
      {
        data: {
          attributes: {
            email: 'foo@bar.com',
            template_id: 'template_123',
            personalisation: { name: 'Foo' },
            email_reply_to_id: 'reply_456',
            reference: 'ref_789',
          },
        },
      }
    end

    let(:headers) do
      {
        'HTTP_AUTHORIZATION' => 'Bearer Trade-Tariff-Test',
        'Accept' => 'application/vnd.hmrc.2.0+json',
        'Content-Type' => 'application/json',
      }
    end

    it 'stores the notification data in the cache and enqueues a job' do
      allow(NotificationsWorker).to receive(:perform_async)
      do_request
      expect(NotificationsWorker).to have_received(:perform_async)
    end

    it 'stores the correct data in the cache' do
      allow(Rails.cache).to receive(:write).and_call_original
      do_request
      expect(Rails.cache).to have_received(:write) do |key, value, _options|
        expect(key).to match(/^notification_/)
        expect(JSON.parse(value, symbolize_names: true)).to eq(params[:data][:attributes])
      end
    end

    it 'returns a 202 Accepted response with the notification ID' do
      do_request
      expect(response).to have_http_status(:accepted)
      response_data = JSON.parse(response.body)['data']
      expect(response_data['id']).to be_a_uuid
      expect(response_data['type']).to eq('notifications')
    end
  end
end
