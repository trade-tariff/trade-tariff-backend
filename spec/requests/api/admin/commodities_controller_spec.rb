RSpec.describe Api::Admin::CommoditiesController, :admin do
  describe 'GET #show' do
    subject(:do_request) do
      authenticated_get api_admin_commodity_path(id: goods_nomenclature.to_admin_param)
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
end
