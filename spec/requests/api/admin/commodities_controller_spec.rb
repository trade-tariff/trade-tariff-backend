RSpec.describe Api::Admin::CommoditiesController, type: :request do
  describe 'GET #index' do
    subject(:do_request) do
      authenticated_get api_commodities_path(format: :csv)
      response.body
    end

    before do
      allow(TariffSynchronizer::FileService).to receive(:get).and_return(StringIO.new("foo,bar\nqux,qul"))
    end

    it 'gets the csv from the FileService' do
      do_request

      expect(TariffSynchronizer::FileService).to have_received(:get).with("uk/goods_nomenclatures/#{Time.zone.today.iso8601}.csv")
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
