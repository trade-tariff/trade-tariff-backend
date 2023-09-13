RSpec.describe Api::Admin::CommoditiesController, type: :request do
  describe 'GET #show' do
    subject(:do_request) do
      authenticated_get api_commodity_path(id: commodity.goods_nomenclature_item_id)
      response
    end

    let(:commodity) { create(:commodity) }

    it_behaves_like 'a successful jsonapi response'
  end

  describe 'GET #index' do
    subject(:do_request) do
      authenticated_get api_commodities_path(format: :csv)
      response.body
    end

    before do
      allow(Reporting::Commodities).to receive(:get_today).and_return(StringIO.new("foo,bar\nqux,qul"))
    end

    it 'gets the csv' do
      do_request

      expect(Reporting::Commodities).to have_received(:get_today)
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
