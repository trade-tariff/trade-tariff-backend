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

      context 'when the user does not exist' do
        before do
          stub_request(:get, "#{host}/api/users/#{username}")
            .to_return(status: 404)
        end

        it { is_expected.to be_nil }
      end

      context 'when api errors' do
        before do
          stub_request(:get, "#{host}/api/users/#{username}")
            .to_return(status: 500)
        end

        it { expect { client }.to raise_error(IdentityApiClient::LookupError, /HTTP 500/) }
      end

      context 'when the request is rate limited' do
        before do
          stub_request(:get, "#{host}/api/users/#{username}")
            .to_return(status: 429)
        end

        it { expect { client }.to raise_error(IdentityApiClient::LookupError, /HTTP 429/) }
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

  describe '.ssl_options' do
    subject(:ssl_options) { described_class.ssl_options }

    context 'when no internal CA is configured' do
      before { allow(TradeTariffBackend).to receive(:internal_ca_pem).and_return(nil) }

      it { is_expected.to eq({}) }
    end

    context 'when an internal CA is configured' do
      let(:certificate) do
        key = OpenSSL::PKey::RSA.new(2048)
        name = OpenSSL::X509::Name.parse('/CN=*.tariff.internal')

        OpenSSL::X509::Certificate.new.tap do |cert|
          cert.version = 2
          cert.serial = 1
          cert.subject = name
          cert.issuer = name
          cert.public_key = key.public_key
          cert.not_before = Time.zone.now
          cert.not_after = 1.hour.from_now
          cert.sign(key, OpenSSL::Digest.new('SHA256'))
        end
      end

      before { allow(TradeTariffBackend).to receive(:internal_ca_pem).and_return(certificate.to_pem) }

      it { is_expected.to include(cert_store: an_instance_of(OpenSSL::X509::Store)) }

      it 'trusts the internal certificate' do
        expect(ssl_options[:cert_store].verify(certificate)).to be true
      end

      it 'still trusts the system CA bundle' do
        bundle = OpenSSL::X509::DEFAULT_CERT_FILE
        skip "no system CA bundle at #{bundle}" unless File.exist?(bundle)

        pem = File.read(bundle)[/-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m]
        skip "no certificates in #{bundle}" if pem.nil?

        expect(ssl_options[:cert_store].verify(OpenSSL::X509::Certificate.new(pem))).to be true
      end
    end
  end
end
