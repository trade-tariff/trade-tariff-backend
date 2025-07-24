RSpec.describe HealthcheckController, type: :request do
  describe 'GET #index' do
    subject(:rendered) { make_request && response }

    let(:make_request) { get '/api/v2/healthcheck' }
    let(:healthcheck) { Healthcheck.instance }

    before do
      allow(Healthcheck).to receive(:new).and_return healthcheck
      allow(healthcheck).to receive(:check).and_return(result)
    end

    context 'when Healthcheck#check returns healthy' do
      let(:result) { { healthy: true } }

      it { is_expected.to have_http_status :success }
      it { is_expected.to have_attributes media_type: /json/ }
      it { expect(rendered.body).to eq '{"healthy":true}' }
    end

    context 'when Healthcheck#check returns unhealthy' do
      let(:result) { { healthy: false } }

      it { is_expected.to have_http_status :service_unavailable }
      it { is_expected.to have_attributes media_type: /json/ }
      it { expect(rendered.body).to eq '{"healthy":false}' }
    end

    context 'when maintenance mode enabled' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('MAINTENANCE').and_return 'true'
      end

      let(:result) { { healthy: true } }

      it { is_expected.to have_http_status :success }
    end
  end
end
