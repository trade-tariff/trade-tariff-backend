RSpec.describe Api::Admin::Chapters::SearchReferencesController do
  it_behaves_like 'v2 search references controller' do
    let(:search_reference_parent)  { create :chapter }
    let(:search_reference)         { create :search_reference, referenced: search_reference_parent }
    let(:collection_query)         do
      { chapter_id: search_reference_parent.goods_nomenclature_item_id.first(2) }
    end
    let(:resource_query) do
      collection_query.merge(id: search_reference.id)
    end
    let(:search_references_collection_path) do
      "/uk/admin/chapters/#{collection_query.fetch(:chapter_id)}/search_references.json"
    end
    let(:search_reference_resource_path) do
      "/uk/admin/chapters/#{resource_query.fetch(:chapter_id)}/search_references/#{resource_query.fetch(:id)}.json"
    end
  end
end
