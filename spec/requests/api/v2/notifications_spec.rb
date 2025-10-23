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
            template_id: 'ce2a0b59-b35b-4f1a-b338-aca0e2ba6f3c',
            personalisation: { name: 'Foo' },
            email_reply_to_id: '64494090-e536-4f1d-8525-53c0eabf8f2c',
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

    context 'when the request is invalid' do
      let(:params) do
        {
          data: {
            attributes: {
              email: 'invalid-email',
              template_id: 'invalid-uuid',
            },
          },
        }
      end

      let(:expected_errors) do
        {
          'errors' => [
            {
              'status' => 422,
              'title' => 'must be a valid e-mail address',
              'detail' => 'Email must be a valid e-mail address',
              'source' => { 'pointer' => '/data/attributes/email' },
            },
            {
              'status' => 422,
              'title' => 'must be a valid UUID',
              'detail' => 'Template must be a valid UUID',
              'source' => { 'pointer' => '/data/attributes/template_id' },
            },
          ],
        }
      end

      it 'returns a 422 Unprocessable Entity response with validation errors' do
        do_request
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to eq(expected_errors)
      end
    end
  end
end
