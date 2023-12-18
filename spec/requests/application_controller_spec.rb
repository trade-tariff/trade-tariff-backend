RSpec.describe ApplicationController, type: :request do
  describe 'GET #index' do
    subject(:do_response) { get('/healthcheck') && response }

    include_context 'with rescued exceptions'

    before do
      allow(Healthcheck).to receive(:check).and_raise(exception, 'foo')
    end

    context 'when the request propagates a server generated error' do
      let(:exception) { StandardError }

      it { is_expected.to have_http_status(:internal_server_error) }
      it { expect(do_response.body).to eq('{"error":"500 - Internal Server Error: Please contact the Tariff team for help with this issue."}') }
    end

    context 'when the request propagates an argument error' do
      let(:exception) { ArgumentError }

      it { is_expected.to have_http_status(:bad_request) }
      it { expect(do_response.body).to eq('{"error":"400 - Bad request: API documentation is available at https://api.trade-tariff.service.gov.uk/"}') }
    end

    context 'when InvalidAuthenticityToken error is raised' do
      let(:exception) { ActionController::InvalidAuthenticityToken }

      it { is_expected.to have_http_status(:unprocessable_entity) }
      it { expect(do_response.body).to eq('{"error":"422 - Unprocessable entity: API documentation is available at https://api.trade-tariff.service.gov.uk/"}') }
    end

    context 'when MethodNotAllowed error is raised' do
      let(:exception) { ActionController::MethodNotAllowed }

      it { is_expected.to have_http_status(:method_not_allowed) }
      it { expect(do_response.body).to eq('{"error":"405 - Method Not Allowed: API documentation is available at https://api.trade-tariff.service.gov.uk/"}') }
    end

    context 'when NotImplemented error is raised' do
      let(:exception) { ActionController::NotImplemented }

      it { is_expected.to have_http_status(:not_implemented) }
      it { expect(do_response.body).to eq('{"error":"501 - Not Implemented: API documentation is available at https://api.trade-tariff.service.gov.uk/"}') }
    end

    context 'when UnknownFormat error is raised' do
      let(:exception) { ActionController::UnknownFormat }

      it { is_expected.to have_http_status(:not_acceptable) }
      it { expect(do_response.body).to eq('{"error":"406 - Not Acceptable: API documentation is available at https://api.trade-tariff.service.gov.uk/"}') }
    end

    shared_examples_for 'a not found request' do |error|
      let(:exception) { error }

      it { is_expected.to have_http_status(:not_found) }
      it { expect(do_response.body).to eq('{"error":"404 - Not Found"}') }
    end

    it_behaves_like 'a not found request', Sequel::RecordNotFound
    it_behaves_like 'a not found request', ActionController::RoutingError
    it_behaves_like 'a not found request', AbstractController::ActionNotFound
  end
end
