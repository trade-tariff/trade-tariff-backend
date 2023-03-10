RSpec.describe HealthcheckController do
  describe 'GET #index' do
    subject(:request_page) { get :index }

    before do
      search_result = Beta::Search::SearchQueryParserResult.new
      service_double = instance_double('Api::Beta::SearchQueryParserService', call: search_result)

      allow(Api::Beta::SearchQueryParserService).to receive(:new).and_return(service_double)
      allow(Healthcheck).to receive(:new).and_return healthcheck
      allow(healthcheck).to receive(:check).and_call_original
    end

    let(:healthcheck) { Healthcheck.instance }

    it { is_expected.to have_http_status :success }
    it { is_expected.to have_attributes media_type: /json/ }

    it 'calls Healthcheck#check' do
      request_page

      expect(healthcheck).to have_received(:check)
    end
  end
end
