describe Api::V1::SearchReferencesController, 'GET to #index' do
  render_views

  let(:heading) { create :heading }
  let!(:search_reference_heading) do
    create :search_reference, heading: heading, heading_id: heading.to_param, title: 'aa'
  end

  let(:chapter) { create :chapter }
  let!(:search_reference_chapter) do
    create :search_reference, heading: nil, chapter: chapter, chapter_id: chapter.to_param, title: 'bb'
  end

  let(:section) { create :section }
  let!(:search_reference_section) do
    create :search_reference, heading: nil, section: section, section_id: section.to_param, title: 'bb'
  end

  context 'with letter param provided' do
    let(:pattern) do
      [
        { id: Integer, title: String, referenced_class: 'Section', referenced_id: String },
        { id: Integer, title: String, referenced_class: 'Chapter', referenced_id: String },
      ]
    end

    it 'performs lookup with provided letter' do
      get :index, params: { query: { letter: 'b' } }, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end

  context 'with no letter param provided' do
    let(:pattern) do
      [
        { id: Integer, title: String, referenced_class: 'Heading', referenced_id: String },
      ]
    end

    it 'peforms lookup with letter A by default' do
      get :index, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end
end
