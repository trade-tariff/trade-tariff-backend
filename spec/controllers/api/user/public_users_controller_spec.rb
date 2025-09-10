RSpec.describe Api::User::PublicUsersController do
  subject(:api_response) { make_request && response }

  routes { UserApi.routes }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    allow(CognitoTokenVerifier).to receive(:verify_id_token).and_return(token)
  end

  describe 'GET #show' do
    let(:make_request) { get :show }

    context 'when token is invalid' do
      let(:token) { nil }

      it_behaves_like 'a unauthorised response for invalid bearer token'
    end

    describe 'when token is for existing user' do
      let!(:user) { create(:public_user) }

      let(:token) do
        {
          'sub' => user.external_id,
          'email' => 'alice@example.com',
        }
      end

      it 'does not create a user' do
        expect {
          get :show
        }.not_to change(PublicUsers::User, :count)
      end

      it { is_expected.to have_http_status :ok }
    end

    describe 'when token is for new user' do
      let(:token) do
        {
          'sub' => '0d6ed044-ab69-43ef-b69a-be84da6eabfc',
          'email' => 'alice@example.com',
        }
      end

      it 'creates a user' do
        expect {
          get :show
        }.to change(PublicUsers::User, :count).by 1
      end

      it { is_expected.to have_http_status :ok }
    end

    describe 'when token is for deleted user' do
      let!(:user) { create(:public_user, :has_been_soft_deleted) }
      let(:token) do
        {
          'sub' => user.external_id,
          'email' => 'alice@example.com',
        }
      end

      it 'creates a user' do
        expect {
          get :show
        }.to change(PublicUsers::User, :count).by 1
      end

      it { is_expected.to have_http_status :ok }
    end
  end

  describe 'PATCH #update' do
    context 'when token is invalid' do
      let(:token) { nil }
      let(:make_request) { patch :update, params: { data: { attributes: { chapter_ids: '12,13,14' } } } }

      it_behaves_like 'a unauthorised response for invalid bearer token'
    end

    context 'when chapter_ids are being updated' do
      let!(:user) { create(:public_user) }
      let(:make_request) { patch :update, params: { data: { attributes: { chapter_ids: '12,13,14' } } } }

      let(:token) do
        {
          'sub' => user.external_id,
          'email' => 'alice@example.com',
        }
      end

      it 'updates the chapter_ids' do
        api_response
        expect(user.chapter_ids).to eq '12,13,14'
      end

      it 'responds with updated chapter details' do
        expect(JSON.parse(api_response.body)['data']['attributes']['chapter_ids']).to eq '12,13,14'
      end

      it { is_expected.to have_http_status :ok }

      context 'with invalid params' do
        let(:make_request) { patch :update, params: { data: { attributes: { chapter_ids: '123' } } } }

        it 'returns errors for user' do
          expected = {
            'errors' => [
              {
                'detail' => 'chapter_ids is invalid',
              },
            ],
          }
          expect(JSON.parse(api_response.body)).to eq expected
        end

        it { is_expected.to have_http_status :unprocessable_content }
      end

      context 'when commodity_codes are being updated' do
        let!(:user) { create(:public_user) }
        let(:make_request) do
          patch :update, params: { data: { attributes: { commodity_codes: %w[1234567890 1234567891] } } }
        end

        let(:token) do
          {
            'sub' => user.external_id,
            'email' => 'alice@example.com',
          }
        end

        it 'updates the commodity_codes' do
          api_response
          expect(user.commodity_codes).to eq %w[1234567890 1234567891]
        end
      end

      context 'when existing commodity_codes exist' do
        let!(:user) { create(:public_user) }

        let(:make_request) do
          patch :update, params: { data: { attributes: { commodity_codes: %w[3333333333 4444444444] } } }
        end

        let(:token) do
          {
            'sub' => user.external_id,
            'email' => 'alice@example.com',
          }
        end

        before do
          user.commodity_codes = %w[1111111111 2222222222]
        end

        it 'removes old codes and saves only the new ones' do
          api_response
          expect(user.reload.commodity_codes).to eq %w[3333333333 4444444444]
        end
      end

      context 'when there aren\'t any commodity codes updated' do
        let!(:user) { create(:public_user) }

        let(:make_request) do
          patch :update, params: { data: { attributes: { commodity_codes: nil } } }
        end

        let(:token) do
          {
            'sub' => user.external_id,
            'email' => 'alice@example.com',
          }
        end

        before do
          user.commodity_codes = %w[1111111111 2222222222]
        end

        it 'keeps the original codes' do
          api_response
          expect(user.reload.commodity_codes).to eq %w[1111111111 2222222222]
        end
      end

      context 'when subscription is being updated' do
        let!(:user) { create(:public_user) }
        let(:make_request) { patch :update, params: { data: { attributes: { stop_press_subscription: active } } } }

        let(:token) do
          {
            'sub' => user.external_id,
            'email' => 'alice@example.com',
          }
        end

        context 'when activating a stop press subscription' do
          let(:active) { true }

          it 'activates the subscription' do
            api_response
            expect(user.stop_press_subscription).to be_a(String)
          end

          it 'responds with updated subscription details' do
            expect(JSON.parse(api_response.body)['data']['attributes']['stop_press_subscription']).to be_a(String)
          end

          it { is_expected.to have_http_status :ok }
        end

        context 'when deactivating a stop press subscription' do
          let(:active) { false }

          it 'deactivates the subscription' do
            api_response
            expect(user.stop_press_subscription).to be false
          end

          it 'responds with updated subscription details' do
            expect(JSON.parse(api_response.body)['data']['attributes']['stop_press_subscription']).to be false
          end

          it { is_expected.to have_http_status :ok }
        end

        context 'when value is empty' do
          let(:active) { '' }

          it 'returns an error' do
            expected = {
              'errors' => [
                {
                  'detail' => 'active is not present',
                },
              ],
            }
            expect(JSON.parse(api_response.body)).to eq expected
          end

          it { is_expected.to have_http_status :unprocessable_content }
        end
      end
    end
  end
end
