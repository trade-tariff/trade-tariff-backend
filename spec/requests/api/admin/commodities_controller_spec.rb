RSpec.describe Api::Admin::CommoditiesController, type: :request do
  describe 'GET #index' do
    subject(:do_request) do
      authenticated_get api_commodities_path(format: :csv)
      response.body
    end

    it 'passes the actual date to the query service' do
      allow(Admin::QueryAllCommodities).to receive(:call)

      do_request

      expect(Admin::QueryAllCommodities).to have_received(:call).with(Time.zone.today.iso8601)
    end

    it_behaves_like 'a successful csv response' do
      let(:make_request) { authenticated_get '/admin/commodities.csv' }
      let(:expected_filename) { "uk-commodities-#{Time.zone.today.iso8601}.csv" }

      before do
        create(:commodity)
      end
    end
  end
end
