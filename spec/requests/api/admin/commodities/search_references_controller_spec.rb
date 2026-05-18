RSpec.describe Api::Admin::Commodities::SearchReferencesController do
  before do
    TradeTariffRequest.time_machine_now = Time.current
  end

  it_behaves_like 'v2 search references controller' do
    let(:search_reference_parent)  { create :commodity, :declarable, :with_heading }
    let(:search_reference)         { create :search_reference, referenced: search_reference_parent }
    let(:collection_query)         do
      { admin_commodity_id: search_reference_parent.goods_nomenclature_item_id }
    end
    let(:resource_query) do
      collection_query.merge(id: search_reference.id)
    end
    let(:to_param) do
      search_reference_parent.to_admin_param
    end
    let(:search_references_collection_path) do
      "/uk/admin/commodities/#{to_param}/search_references.json"
    end
    let(:search_reference_resource_path) do
      "/uk/admin/commodities/#{to_param}/search_references/#{resource_query.fetch(:id)}.json"
    end
  end

  describe 'POST to #create' do
    subject(:api_response) do
      make_request
      response
    end

    let(:make_request) do
      post "/uk/admin/commodities/#{params.fetch(:admin_commodity_id)}/search_references", params: params.except(:admin_commodity_id), headers: request_headers, as: :json
    end

    let(:referenced) { create(:commodity, :with_heading, goods_nomenclature_item_id: '0101110000', producline_suffix: '80') }

    context 'when passing a productline suffix' do
      let(:params) do
        {
          data: { type: :search_reference, attributes: { title: 'foo' } },
          admin_commodity_id: "#{referenced.goods_nomenclature_item_id}-#{referenced.producline_suffix}",
        }
      end

      it { is_expected.to have_http_status(:created) }
      it { expect { api_response }.to change(SearchReference, :count).by(1) }

      it 'creates a search reference with the correct attributes' do
        api_response

        expect(SearchReference.last).to have_attributes(
          referenced_class: 'Commodity',
          productline_suffix: '80',
          goods_nomenclature_item_id: '0101110000',
          goods_nomenclature_sid: be_a(Integer),
        )
      end
    end

    context 'when passing an unmatched productline suffix' do
      let(:params) do
        {
          data: { type: :search_reference, attributes: { title: 'foo' } },
          admin_commodity_id: "#{referenced.goods_nomenclature_item_id}-75",
        }
      end

      it { is_expected.to have_http_status(:not_found) }
      it { expect { api_response }.not_to change(SearchReference, :count) }
    end

    context 'when not passing a productline suffix' do
      let(:params) do
        {
          data: { type: :search_reference, attributes: { title: 'foo' } },
          admin_commodity_id: referenced.goods_nomenclature_item_id, # This is missing the productline suffix
        }
      end

      it { is_expected.to have_http_status(:created) }
      it { expect { api_response }.to change(SearchReference, :count).by(1) }

      it 'creates a search reference with the correct attributes' do
        api_response

        expect(SearchReference.last).to have_attributes(
          referenced_class: 'Commodity',
          productline_suffix: '80',
          goods_nomenclature_item_id: '0101110000',
          goods_nomenclature_sid: be_a(Integer),
        )
      end
    end

    context 'when passing a subheading' do
      let(:referenced) { create(:commodity, goods_nomenclature_item_id: '0101110000', producline_suffix: '10') }

      let(:params) do
        {
          data: { type: :search_reference, attributes: { title: 'foo' } },
          admin_commodity_id: "#{referenced.goods_nomenclature_item_id}-#{referenced.producline_suffix}",
        }
      end

      it { is_expected.to have_http_status(:created) }
      it { expect { api_response }.to change(SearchReference, :count).by(1) }

      it 'creates a search reference with the correct attributes' do
        api_response

        expect(SearchReference.last).to have_attributes(
          referenced_class: 'Subheading',
          productline_suffix: '10',
          goods_nomenclature_item_id: '0101110000',
          goods_nomenclature_sid: be_a(Integer),
        )
      end
    end
  end
end
