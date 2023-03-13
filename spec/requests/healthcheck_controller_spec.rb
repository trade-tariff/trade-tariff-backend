RSpec.describe HealthcheckController, type: :request do
  describe 'GET #index' do
    subject(:rendered) { make_request && response }

    let(:make_request) { get '/healthcheck' }
    let(:healthcheck) { Healthcheck.instance }

    before do
      search_result = Beta::Search::SearchQueryParserResult.new
      service_double = instance_double('Api::Beta::SearchQueryParserService', call: search_result)

      allow(Api::Beta::SearchQueryParserService).to receive(:new).and_return(service_double)
      allow(Healthcheck).to receive(:new).and_return healthcheck
      allow(healthcheck).to receive(:check).and_call_original
    end

    it 'calls Healthcheck#check' do
      rendered

      expect(healthcheck).to have_received(:check)
    end

    context 'when Healthcheck#check returns healthy' do
      before do
        allow(healthcheck).to receive(:check).and_return(healthy: true)
      end

      it { is_expected.to have_http_status :success }
      it { is_expected.to have_attributes media_type: /json/ }
      it { expect(rendered.body).to eq '{"healthy":true}' }
    end

    context 'when Healthcheck#check returns unhealthy' do
      before do
        allow(healthcheck).to receive(:check).and_return(healthy: false)
      end

      it { is_expected.to have_http_status :service_unavailable }
      it { is_expected.to have_attributes media_type: /json/ }
      it { expect(rendered.body).to eq '{"healthy":false}' }
    end
  end
end
