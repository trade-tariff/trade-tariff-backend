RSpec.describe Api::Admin::Chapters::SearchReferencesController do
  it_behaves_like 'v2 search references controller' do
    let(:search_reference_parent)  { create :chapter }
    let(:search_reference)         { create :search_reference, chapter_id: search_reference_parent.short_code }
    let(:collection_query)         do
      { chapter_id: search_reference_parent.goods_nomenclature_item_id.first(2) }
    end
    let(:resource_query) do
      collection_query.merge(id: search_reference.id)
    end
  end
end
