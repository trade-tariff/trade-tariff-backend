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

    context 'when activating the subscription' do
      let(:active) { true }

      it 'activates the subscription' do
        api_response
        expect(user.public_send(subscription_type)).to be_a(String)
      end

      it 'responds with updated subscription details' do
        expect(
          JSON.parse(api_response.body)['data']['attributes'][subscription_type.to_s],
        ).to be_a(String)
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
        expect(
          JSON.parse(api_response.body)['data']['attributes'][subscription_type.to_s],
        ).to be(false)
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
