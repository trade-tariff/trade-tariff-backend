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
      def jwt_with_claims(claims)
        payload = Base64.urlsafe_encode64(claims.to_json, padding: false)
        "header.#{payload}.signature"
      end

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

      it 'extracts client_id from a Bearer JWT with a client_id claim' do
        token = jwt_with_claims('client_id' => 'my-client', 'sub' => 'my-subject')
        payload = process_action_payload_for(
          params: {},
          headers: { 'Authorization' => "Bearer #{token}" },
        )

        expect(payload[:client_id]).to eq('my-client')
      end

      it 'falls back to sub when the JWT has no client_id claim' do
        token = jwt_with_claims('sub' => 'my-subject')
        payload = process_action_payload_for(
          params: {},
          headers: { 'Authorization' => "Bearer #{token}" },
        )

        expect(payload[:client_id]).to eq('my-subject')
      end

      it 'sets client_id to nil when the Authorization header is absent' do
        payload = process_action_payload_for(params: {}, headers: {})

        expect(payload[:client_id]).to be_nil
      end

      it 'sets client_id to nil for a non-JWT bearer token with no X-Client-Id header' do
        payload = process_action_payload_for(
          params: {},
          headers: { 'Authorization' => 'Bearer not-a-jwt' },
        )

        expect(payload[:client_id]).to be_nil
      end

      it 'falls back to X-Client-Id header when no JWT is present' do
        payload = process_action_payload_for(
          params: {},
          headers: { 'X-Client-Id' => 'apigw-key-id-abc123' },
        )

        expect(payload[:client_id]).to eq('apigw-key-id-abc123')
      end

      it 'prefers JWT client_id over X-Client-Id header' do
        token = jwt_with_claims('client_id' => 'jwt-client')
        payload = process_action_payload_for(
          params: {},
          headers: {
            'Authorization' => "Bearer #{token}",
            'X-Client-Id' => 'apigw-key-id-abc123',
          },
        )

        expect(payload[:client_id]).to eq('jwt-client')
      end
    end

    context 'with logger tagging' do
      def jwt_with_claims(claims)
        payload = Base64.urlsafe_encode64(claims.to_json, padding: false)
        "header.#{payload}.signature"
      end

      it 'tags log output with client_id from the Bearer JWT' do
        token = jwt_with_claims('client_id' => 'tagged-client')
        tagged_with = nil

        allow(Rails.logger).to receive(:tagged) do |tag, &block|
          tagged_with = tag
          block.call
        end

        api_get('/uk/api/healthcheck', headers: { 'Authorization' => "Bearer #{token}" })

        expect(tagged_with).to eq('tagged-client')
      end

      it 'tags log output with "anonymous" when no token is present' do
        tagged_with = nil

        allow(Rails.logger).to receive(:tagged) do |tag, &block|
          tagged_with = tag
          block.call
        end

        api_get('/uk/api/healthcheck')

        expect(tagged_with).to eq('anonymous')
      end
    end
  end
end
