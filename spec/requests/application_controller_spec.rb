RSpec.describe ApplicationController, type: :request do
  describe 'GET #index' do
    subject(:api_response) do
      make_request
      response
    end

    let(:make_request) { api_get('/uk/api/healthcheck') }

    context 'when the request propagates a handled error' do
      before do
        allow(Healthcheck).to receive(:check).and_raise(exception, 'foo')
      end

      let(:exception) { ActionController::InvalidAuthenticityToken }

      let(:expected_error) do
        {
          "errors": [
            {
              "detail": '422 - Unprocessable content: API documentation is available at https://api.trade-tariff.service.gov.uk/',
            },
          ],
        }.to_json
      end

      it { is_expected.to have_http_status(:unprocessable_content) }
      it { expect(api_response.body).to eq(expected_error) }
    end

    context 'with invalid dates' do
      before do
        allow(TimeMachine).to receive(:at).and_call_original

        api_response
      end

      context 'when as_of is out of range' do
        subject(:api_response) do
          make_request
          response
        end

        let(:make_request) { api_get('/uk/api/healthcheck', params: { as_of: '2023000-01-01' }) }

        it { expect(TimeMachine).to have_received(:at).with(Time.zone.today) }
      end

      context 'when as_of has year zero' do
        subject(:api_response) do
          make_request
          response
        end

        let(:make_request) { api_get('/uk/api/healthcheck', params: { as_of: '0000-05-24' }) }

        it { expect(TimeMachine).to have_received(:at).with(Time.zone.today) }
      end

      context 'when as_of is in range' do
        subject(:api_response) do
          make_request
          response
        end

        let(:make_request) { api_get('/uk/api/healthcheck', params: { as_of: '2024-01-01' }) }

        it { expect(TimeMachine).to have_received(:at).with(Date.new(2024, 1, 1)) }
      end
    end

    context 'with Link header' do
      it 'includes the API docs link header on every response' do
        api_get('/uk/api/healthcheck')

        expect(response.headers['Link']).to eq('<https://api-docs.trade-tariff.service.gov.uk/llms.txt>; rel="describedby"')
      end
    end

    context 'with security headers', :aggregate_failures do
      it 'includes the default security headers on every response' do
        api_get('/uk/api/healthcheck')

        expect(response.headers['X-Frame-Options']).to eq('DENY')
        expect(response.headers['Content-Security-Policy']).to eq("default-src 'none'; frame-ancestors 'none'")
      end
    end

    context 'with request logging payload' do
      def process_action_payload_for(params:, headers: {})
        events = []
        subscriber = ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*args|
          events << ActiveSupport::Notifications::Event.new(*args)
        end

        api_get('/uk/api/healthcheck', params:, headers:)

        events.last.payload
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
      end

      it 'adds the current request_id to the action controller payload' do
        payload = process_action_payload_for(params: { request_id: 'search-request-id' })

        expect(payload[:request_id]).to eq('search-request-id')
      end

      it 'bounds request_id values added to the action controller payload' do
        long_request_id = 'a' * 101
        payload = process_action_payload_for(params: { request_id: long_request_id })

        expect(payload[:request_id]).to eq('a' * ApplicationController::MAX_LOGGED_REQUEST_ID_LENGTH)
      end

      it 'falls back to the Rails request id when the search request_id is blank' do
        payload = process_action_payload_for(params: { request_id: '' })

        expect(payload[:request_id]).to be_present
        expect(payload[:request_id].length).to be <= ApplicationController::MAX_LOGGED_REQUEST_ID_LENGTH
      end

      it 'classifies requests from the frontend user agent' do
        payload = process_action_payload_for(
          params: { request_id: 'search-request-id' },
          headers: { 'HTTP_USER_AGENT' => 'TradeTariffFrontend/a4d021c2' },
        )

        expect(payload[:request_source]).to eq('frontend')
      end

      it 'classifies non-frontend requests as backend_only' do
        payload = process_action_payload_for(
          params: { request_id: 'search-request-id' },
          headers: { 'HTTP_USER_AGENT' => 'curl/8.0.1' },
        )

        expect(payload[:request_source]).to eq('backend_only')
      end

      it 'prefers the original user agent header for request source classification' do
        payload = process_action_payload_for(
          params: { request_id: 'search-request-id' },
          headers: {
            'HTTP_X_ORIGINAL_USER_AGENT' => 'TradeTariffFrontend/a4d021c2',
            'HTTP_USER_AGENT' => 'curl/8.0.1',
          },
        )

        expect(payload[:user_agent]).to eq('TradeTariffFrontend/a4d021c2')
        expect(payload[:request_source]).to eq('frontend')
      end

      it 'classifies blank user agents as backend_only' do
        payload = process_action_payload_for(
          params: { request_id: 'search-request-id' },
          headers: {
            'HTTP_X_ORIGINAL_USER_AGENT' => '',
            'HTTP_USER_AGENT' => '',
          },
        )

        expect(payload[:request_source]).to eq('backend_only')
      end
    end
  end
end
