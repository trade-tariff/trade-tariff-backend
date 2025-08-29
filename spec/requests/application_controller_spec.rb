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
              "detail": '422 - Unprocessable entity: API documentation is available at https://api.trade-tariff.service.gov.uk/',
            },
          ],
        }.to_json
      end

      it { is_expected.to have_http_status(:unprocessable_content) }
      it { expect(do_response.body).to eq(expected_error) }
    end
  end
end
