RSpec.describe Api::Admin::Headings::SearchReferencesController do
  routes { AdminApi.routes }

  it_behaves_like 'v2 search references controller' do
    let(:search_reference_parent)  { create :heading }
    let(:search_reference)         { create :search_reference, referenced: search_reference_parent }
    let(:collection_query)         do
      { heading_id: search_reference_parent.goods_nomenclature_item_id.first(4) }
    end
    let(:resource_query) do
      collection_query.merge(id: search_reference.id)
    end
  end
end
