RSpec.describe EvalAppClient do
  let(:eval_app_url) { 'http://eval-app.test' }

  before do
    allow(TradeTariffBackend).to receive_messages(
      eval_app_url:, eval_app_auth_token: 'test-token', user_agent: 'TradeTariffBackend/test',
    )
  end

  describe '.start_run!' do
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
