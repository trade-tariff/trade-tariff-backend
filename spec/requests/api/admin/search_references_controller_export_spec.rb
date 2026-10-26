RSpec.describe Api::Admin::SearchReferencesController, :admin do
  describe 'GET #export' do
    subject(:api_response) do
      authenticated_get export_api_search_references_path
      response
    end

    before do
      TradeTariffRequest.time_machine_now = Time.current
      create(:search_reference, title: 'gift')
    end

    it { is_expected.to have_http_status(:ok) }

    it 'returns a CSV attachment', :aggregate_failures do
      expect(api_response.media_type).to eq('text/csv')
      expect(api_response.headers['Content-Disposition']).to match(/attachment; filename="search_references_\w+_\d{4}_\d{2}_\d{2}\.csv"/)
      expect(api_response.body).to include('Search reference ID', 'gift')
    end
  end
end
