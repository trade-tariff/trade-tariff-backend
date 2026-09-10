RSpec.describe IdentityApiClient do
  describe '.get_email' do
    subject(:client) { described_class.get_email(username) }

    context 'when username is nil' do
      let(:username) { nil }

      it { is_expected.to be_nil }
    end

    context 'with username' do
      let(:username) { '123abc' }
      let(:host) { 'https://identity.api' }
      let(:expected_response) do
        {
          'user' => {
            'email' => 'email@example.com',
          },
        }
      end

      before do
        allow(TradeTariffBackend).to receive(:identity_api_host).and_return(host)
        stub_request(:get, "#{host}/api/users/#{username}")
          .to_return(status: 200, body: expected_response.to_json)
      end

      it { is_expected.to eq 'email@example.com' }

      context 'when api errors' do
        before do
          stub_request(:get, "#{host}/api/users/#{username}")
            .to_return(status: 500)
        end

        it { is_expected.to be_nil }
      end
    end
  end

  describe '.delete_user' do
    subject(:client) { described_class.delete_user(username) }

    context 'when username is nil' do
      let(:username) { nil }

      it { is_expected.to be_nil }
    end

    context 'with username' do
      let(:username) { '123abc' }
      let(:host) { 'https://identity.api' }

      before do
        allow(TradeTariffBackend).to receive(:identity_api_host).and_return(host)
        stub_request(:delete, "#{host}/api/users/#{username}")
          .to_return(status: 200)
      end

      it { is_expected.to be true }

      # The identity service answers a delete for an unknown user with 200: it
      # rescues UserNotFoundException and reports success. A 404 therefore means
      # the request never reached the endpoint, so treating it as a completed
      # deletion would clear external_id while the Cognito user still exists.
      context 'when the request does not reach the endpoint' do
        before do
          stub_request(:delete, "#{host}/api/users/#{username}")
            .to_return(status: 404)
        end

        it { expect { client }.to raise_error(IdentityApiClient::DeletionError, /HTTP 404/) }
      end

      context 'when api errors' do
        before do
          stub_request(:delete, "#{host}/api/users/#{username}")
            .to_return(status: 500)
        end

        it { expect { client }.to raise_error(IdentityApiClient::DeletionError, /HTTP 500/) }
      end

      context 'when the request is rate limited' do
        before do
          stub_request(:delete, "#{host}/api/users/#{username}")
            .to_return(status: 429)
        end

        it { expect { client }.to raise_error(IdentityApiClient::DeletionError, /HTTP 429/) }
      end
    end
  end
end
