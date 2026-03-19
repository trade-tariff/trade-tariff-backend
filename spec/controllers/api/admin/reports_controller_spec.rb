RSpec.describe Api::Admin::ReportsController do
  routes { AdminApi.routes }

  describe 'GET #index' do
    before do
      allow(TradeTariffBackend).to receive_messages(service: service, reporting_cdn_host: nil)
      allow(Reporting::Commodities).to receive(:available_today?).and_return(true)
      allow(Reporting::SupplementaryUnits).to receive(:available_today?).and_return(true)
      get :index
    end

    context 'when on the UK service' do
      let(:service) { 'uk' }

      it { expect(response).to have_http_status(:ok) }
      it { expect(response.parsed_body['data'].map { |item| item['id'] }).to include('differences') }
      it { expect(response.parsed_body['data'].map { |item| item['id'] }).not_to include('category_assessments') }
    end

    context 'when dependencies are missing for differences' do
      let(:service) { 'uk' }

      before do
        allow(Reporting::Commodities).to receive(:available_today?).and_return(false)
        allow(Reporting::SupplementaryUnits).to receive(:available_today?).and_return(true)
        get :index
      end

      it 'returns the missing dependency labels' do
        differences = response.parsed_body['data'].find { |item| item['id'] == 'differences' }

        expect(differences.dig('attributes', 'dependencies_missing')).to be(true)
        expect(differences.dig('attributes', 'missing_dependencies')).to include('UK commodities report', 'XI commodities report')
      end
    end

    context 'when on the XI service' do
      let(:service) { 'xi' }

      it { expect(response).to have_http_status(:ok) }
      it { expect(response.parsed_body['data'].map { |item| item['id'] }).to include('category_assessments') }
      it { expect(response.parsed_body['data'].map { |item| item['id'] }).not_to include('differences') }
    end
  end

  describe 'GET #show' do
    before do
      allow(Reporting::Differences).to receive(:available_today?).and_return(true)
      allow(Reporting::Commodities).to receive(:available_today?).and_return(true)
      allow(Reporting::SupplementaryUnits).to receive(:available_today?).and_return(true)
      allow(TradeTariffBackend).to receive_messages(reporting_cdn_host: nil, service: 'uk')
      get :show, params: { id: 'differences' }
    end

    it { expect(response).to have_http_status(:ok) }
    it { expect(response.parsed_body.dig('data', 'id')).to eq('differences') }
  end

  describe 'POST #run' do
    before do
      allow(TradeTariffBackend).to receive_messages(service: 'uk', reporting_cdn_host: nil)
      allow(ReportTriggerWorker).to receive(:perform_async)
      post :run, params: { id: 'commodities' }
    end

    it { expect(response).to have_http_status(:accepted) }
    it { expect(ReportTriggerWorker).to have_received(:perform_async).with('commodities') }
  end

  describe 'GET #download' do
    before do
      allow(TradeTariffBackend).to receive_messages(service: 'uk', reporting_cdn_host: nil)
    end

    context 'when the report is available' do
      before do
        allow(Reporting::Commodities).to receive_messages(available_today?: true, download_link_today: 'https://reporting.example/uk/report.csv')
        get :download, params: { id: 'commodities' }
      end

      it { expect(response).to redirect_to('https://reporting.example/uk/report.csv') }
    end

    context 'when the report is not available' do
      before do
        allow(Reporting::Commodities).to receive(:available_today?).and_return(false)
        get :download, params: { id: 'commodities' }
      end

      it { expect(response).to have_http_status(:not_found) }
    end
  end
end
