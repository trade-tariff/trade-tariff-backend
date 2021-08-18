describe Api::V1::Commodities::SearchReferencesController do
  it_behaves_like 'v1 search references controller' do
    let(:search_reference_parent)  { create :commodity, :declarable }
    let(:search_reference)         { create :search_reference, commodity_id: search_reference_parent.code }
    let(:collection_query)         do
      { commodity_id: search_reference_parent.goods_nomenclature_item_id }
    end
    let(:resource_query) do
      collection_query.merge(id: search_reference.id)
    end
  end
end
