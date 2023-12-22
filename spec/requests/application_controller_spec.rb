RSpec.describe ApplicationController, type: :request do
  describe 'GET #index' do
    subject(:do_response) { get('/healthcheck') && response }

    context 'when the request propagates a handled error' do
      before do
        allow(Healthcheck).to receive(:check).and_raise(exception, 'foo')
      end

      let(:exception) { ActionController::InvalidAuthenticityToken }

      it { is_expected.to have_http_status(:unprocessable_entity) }
      it { expect(do_response.body).to eq('{"error":"422 - Unprocessable entity: API documentation is available at https://api.trade-tariff.service.gov.uk/"}') }
    end
  end
end
