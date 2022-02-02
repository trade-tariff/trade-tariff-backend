RSpec.describe Api::Admin::Commodities::SearchReferencesController do
  it_behaves_like 'v2 search references controller' do
    let(:search_reference_parent)  { create :commodity, :declarable, :with_heading }
    let(:search_reference)         { create :search_reference, commodity_id: search_reference_parent.code }
    let(:collection_query)         do
      { commodity_id: search_reference_parent.goods_nomenclature_item_id }
    end
    let(:resource_query) do
      collection_query.merge(id: search_reference.id)
    end
    let(:to_param) do
      search_reference_parent.admin_id
    end
  end

  describe 'POST to #create' do
    subject(:do_post) { post :create, params: params }

    before { login_as_api_user }

    let(:referenced) { create(:commodity, :with_heading, goods_nomenclature_item_id: '0101110000', producline_suffix: '80') }

    context 'when passing a productline suffix' do
      let(:params) do
        {
          data: { type: :search_reference, attributes: { title: 'foo' } },
          commodity_id: "#{referenced.goods_nomenclature_item_id}-#{referenced.producline_suffix}",
        }
      end

      it { is_expected.to have_http_status(:created) }
      it { expect { do_post }.to change(SearchReference, :count).by(1) }

      it 'creates a search reference with the correct attributes' do
        do_post

        expect(SearchReference.last).to have_attributes(
          referenced_class: 'Commodity',
          referenced_id: '0101110000',
          productline_suffix: '80',
        )
      end
    end

    context 'when passing an unmatched productline suffix' do
      let(:params) do
        {
          data: { type: :search_reference, attributes: { title: 'foo' } },
          commodity_id: "#{referenced.goods_nomenclature_item_id}-75",
        }
      end

      it { is_expected.to have_http_status(:not_found) }
      it { expect { do_post }.not_to change(SearchReference, :count) }
    end

    context 'when not passing a productline suffix' do
      let(:params) do
        {
          data: { type: :search_reference, attributes: { title: 'foo' } },
          commodity_id: referenced.goods_nomenclature_item_id, # This is missing the productline suffix
        }
      end

      it { is_expected.to have_http_status(:created) }
      it { expect { do_post }.to change(SearchReference, :count).by(1) }

      it 'creates a search reference with the correct attributes' do
        do_post

        expect(SearchReference.last).to have_attributes(
          referenced_class: 'Commodity',
          referenced_id: '0101110000',
          productline_suffix: '80',
        )
      end
    end

    context 'when passing a subheading' do
      let(:referenced) { create(:commodity, goods_nomenclature_item_id: '0101110000', producline_suffix: '10') }

      let(:params) do
        {
          data: { type: :search_reference, attributes: { title: 'foo' } },
          commodity_id: "#{referenced.goods_nomenclature_item_id}-#{referenced.producline_suffix}",
        }
      end

      it { is_expected.to have_http_status(:created) }
      it { expect { do_post }.to change(SearchReference, :count).by(1) }

      it 'creates a search reference with the correct attributes' do
        do_post

        expect(SearchReference.last).to have_attributes(
          referenced_class: 'Subheading',
          referenced_id: '0101110000',
          productline_suffix: '10',
        )
      end
    end
  end
end
