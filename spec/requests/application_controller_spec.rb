RSpec.describe ApplicationController, type: :request do
  describe 'GET #index' do
    subject(:do_response) { api_get('/uk/api/healthcheck') && response }

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
      it { expect(do_response.body).to eq(expected_error) }
    end

    context 'with invalid dates' do
      before do
        allow(TimeMachine).to receive(:at).and_call_original

        do_response
      end

      context 'when as_of is out of range' do
        subject(:do_response) { api_get('/uk/api/healthcheck', params: { as_of: '2023000-01-01' }) && response }

        it { expect(TimeMachine).to have_received(:at).with(Time.zone.today) }
      end

      context 'when as_of is in range' do
        subject(:do_response) { api_get('/uk/api/healthcheck', params: { as_of: '2024-01-01' }) && response }

        it { expect(TimeMachine).to have_received(:at).with(Date.new(2024, 1, 1)) }
      end
    end
  end
end
