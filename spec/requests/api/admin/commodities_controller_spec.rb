RSpec.describe Api::Admin::CommoditiesController, type: :request do
  describe 'GET #show' do
    subject(:do_request) do
      authenticated_get api_commodity_path(id: goods_nomenclature.to_admin_param)
      response
    end

    context 'when fetching a commodity' do
      let(:goods_nomenclature) do
        create(
          :commodity,
          goods_nomenclature_item_id: '0101010100',
          producline_suffix: '80',
        )
      end

      it_behaves_like 'a successful jsonapi response'

      it 'returns the commodity' do
        json_response = JSON.parse(do_request.body)

        expect(json_response.dig('data', 'id')).to eq('0101010100')
      end
    end

    context 'when fetching a subheading' do
      let(:goods_nomenclature) do
        create(
          :subheading,
          goods_nomenclature_item_id: '0101010100',
          producline_suffix: '10',
        )
      end

      it_behaves_like 'a successful jsonapi response'

      it 'returns the subheading' do
        json_response = JSON.parse(do_request.body)

        expect(json_response.dig('data', 'id')).to eq('0101010100-10')
      end
    end
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
