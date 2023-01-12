class NullService
  def self.call; end
end

RSpec.describe ApplicationController, type: :controller do
  controller do
    def index
      render plain: NullService.call
    end
  end

  xdescribe 'GET #index' do
    subject(:do_response) { get :index }

    before do
      allow(NullService).to receive(:call).and_raise(exception, 'foo')
    end

    context 'when the request propagates a server generated error' do
      let(:exception) { StandardError }

      it { is_expected.to have_http_status(:internal_server_error) }
      it { expect(do_response.body).to eq('{"error":"500 - Internal Server Error: Please contact the Tariff team for help with this issue."}') }
    end

    context 'when the request propagates an argument error' do
      let(:exception) { ArgumentError }

      it { is_expected.to have_http_status(:bad_request) }
      it { expect(do_response.body).to eq('{"error":"400 - Bad request: foo"}') }
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
