RSpec.shared_examples_for 'a user controller subscription type update' do |subscription_type|
  context "when updating the #{subscription_type} subscription" do
    let!(:user) { create(:public_user) }
    let(:make_request) do
      patch :update, params: {
        data: {
          attributes: { subscription_type => active },
        },
      }
    end

    let(:token) do
      {
        'sub' => user.external_id,
        'email' => 'alice@example.com',
      }
    end

    let(:verify_result) { CognitoTokenVerifier::Result.new(valid: true, payload: token, reason: nil) }

    before do
      request.headers['Authorization'] = 'Bearer test-token'
      allow(CognitoTokenVerifier).to receive(:verify_id_token).and_return(verify_result)
    end

    context 'when activating the subscription' do
      let(:active) { true }

      it 'activates the subscription' do
        api_response
        expect(user.public_send(subscription_type)).to be_a(String)
      end

      it 'responds with updated subscription details' do
        body = JSON.parse(api_response.body)
        response = body['data']['attributes']['subscriptions'][0]

        expect(response['active']).to be(true)
        expect(response['subscription_type']).to eq(subscription_type.to_s.sub('_subscription', ''))
        expect(response['id']).to be_a(String)
      end

      it { is_expected.to have_http_status :ok }
    end

    context 'when deactivating the subscription' do
      let(:active) { false }

      it 'deactivates the subscription' do
        api_response
        expect(user.public_send(subscription_type)).to be(false)
      end

      it 'responds with updated subscription details' do
        body = JSON.parse(api_response.body)
        response = body['data']['attributes']['subscriptions'][0]

        expect(response['active']).to be(false)
        expect(response['subscription_type']).to eq(subscription_type.to_s.sub('_subscription', ''))
        expect(response['id']).to be_a(String)
      end

      it { is_expected.to have_http_status :ok }
    end

    context 'when value is empty' do
      let(:active) { '' }

      it 'returns an error' do
        expected = {
          'errors' => [
            { 'detail' => 'active is not present' },
          ],
        }
        expect(JSON.parse(api_response.body)).to eq(expected)
      end

      it { is_expected.to have_http_status :unprocessable_content }
    end
  end
end
