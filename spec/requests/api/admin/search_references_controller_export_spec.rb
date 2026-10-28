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
      expect(api_response.body).not_to include(
        'Label description',
        'Label synonyms',
        'Label colloquial terms',
        'Label known brands',
        'Label stale',
        'Label needs review',
        'Label approved',
        'Label manually edited',
        'Label expired',
      )
    end

    it 'includes label columns when requested' do
      authenticated_get export_api_search_references_path, params: { include_ai_labels: true }

      expect(response.body).to include(
        'Label description',
        'Label synonyms',
        'Label colloquial terms',
        'Label known brands',
        'Label stale',
        'Label needs review',
        'Label approved',
        'Label manually edited',
        'Label expired',
      )
    end
  end
end
