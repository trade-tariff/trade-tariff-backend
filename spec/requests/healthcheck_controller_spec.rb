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
  end
end
