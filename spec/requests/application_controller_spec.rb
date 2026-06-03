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

    context 'with request logging payload' do
      it 'adds the current request_id to the action controller payload' do
        events = []
        subscriber = ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*args|
          events << ActiveSupport::Notifications::Event.new(*args)
        end

        api_get('/uk/api/healthcheck', params: { request_id: 'search-request-id' })

        payload = events.last.payload
        expect(payload[:request_id]).to eq('search-request-id')
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
      end
    end
  end
end
