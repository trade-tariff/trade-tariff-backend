describe Api::V1::Sections::SearchReferencesController do
  it_behaves_like 'v1 search references controller' do
    let(:search_reference_parent)  { create :section }
    let(:search_reference)         { create :search_reference, referenced: search_reference_parent }
    let(:collection_query)         do
      { section_id: search_reference_parent.id }
    end
    let(:resource_query) do
      collection_query.merge(id: search_reference.id)
    end
  end
end
