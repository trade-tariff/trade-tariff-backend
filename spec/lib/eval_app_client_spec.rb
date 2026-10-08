RSpec.describe EvalAppClient do
  let(:eval_app_url) { 'http://eval-app.test' }

  before do
    allow(TradeTariffBackend).to receive_messages(
      eval_app_url:, eval_app_auth_token: 'test-token', user_agent: 'TradeTariffBackend/test',
    )
    # self.client memoizes @client at the class level — without resetting it, whichever example
    # (in this file or any other spec run before it) builds the connection first "wins", and every
    # later example's eval_app_url/eval_app_timeout stubs are silently ignored. Same convention
    # openai_client_spec.rb already uses for the same reason.
    described_class.instance_variable_set(:@client, nil)
  end

  describe '.client' do
    it 'sets short timeouts, since /start is fire-and-forget and must fail fast rather than hang the request' do
      expect(described_class.client.options.open_timeout).to eq(TradeTariffBackend.eval_app_open_timeout)
      expect(described_class.client.options.timeout).to eq(TradeTariffBackend.eval_app_timeout)
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

      it 'trusts the eval app presenting that certificate, not just the public CA bundle' do
        expect(described_class.client.ssl.cert_store.verify(certificate)).to be true
      end
    end

    context 'when no internal CA is configured' do
      before { allow(TradeTariffBackend).to receive(:internal_ca_pem).and_return(nil) }

      it 'behaves as before: ordinary certificate checking, nothing extra trusted' do
        expect(described_class.client.ssl.cert_store).to be_nil
      end
    end
  end

  describe '.start_run!' do
    context 'when EVAL_APP_URL is not configured' do
      before { allow(TradeTariffBackend).to receive(:eval_app_url).and_return(nil) }

      it 'raises EvalAppClient::Error without attempting a request' do
        expect { described_class.start_run!('107') }.to raise_error(EvalAppClient::Error, /EVAL_APP_URL is not configured/)
        expect(WebMock).not_to have_requested(:post, %r{/start})
      end
    end

    context 'when the eval app accepts the run' do
      before { stub_request(:post, "#{eval_app_url}/api/evaluation/runs/107/start").to_return(status: 202) }

      it 'sends the configured bearer token' do
        described_class.start_run!('107')

        expect(WebMock).to have_requested(:post, "#{eval_app_url}/api/evaluation/runs/107/start")
          .with(headers: { 'Authorization' => 'Bearer test-token' })
      end

      it 'does not raise' do
        expect { described_class.start_run!('107') }.not_to raise_error
      end
    end

    context 'when the eval app reports the run is already being executed (409)' do
      before { stub_request(:post, "#{eval_app_url}/api/evaluation/runs/107/start").to_return(status: 409) }

      it 'does not raise — already started counts as success' do
        expect { described_class.start_run!('107') }.not_to raise_error
      end
    end

    context 'when the eval app returns a genuine error status' do
      before { stub_request(:post, "#{eval_app_url}/api/evaluation/runs/107/start").to_return(status: 401) }

      it 'raises EvalAppClient::Error' do
        expect { described_class.start_run!('107') }.to raise_error(EvalAppClient::Error, /401/)
      end
    end

    context 'when a transient connection error occurs then succeeds' do
      before do
        call_count = 0
        stub_request(:post, "#{eval_app_url}/api/evaluation/runs/107/start").to_return do
          call_count += 1
          call_count == 1 ? raise(Faraday::ConnectionFailed, 'connection reset') : { status: 202 }
        end
      end

      it 'retries once and succeeds' do
        expect { described_class.start_run!('107') }.not_to raise_error
      end
    end

    context 'when connection errors persist' do
      before do
        allow(Kernel).to receive(:sleep)
        stub_request(:post, "#{eval_app_url}/api/evaluation/runs/107/start")
          .to_raise(Faraday::ConnectionFailed.new('connection reset'))
      end

      it 'raises EvalAppClient::Error after exhausting retries' do
        expect { described_class.start_run!('107') }.to raise_error(EvalAppClient::Error, /could not reach/)
        expect(WebMock).to have_requested(:post, "#{eval_app_url}/api/evaluation/runs/107/start").times(2)
      end
    end
  end
end
