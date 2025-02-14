RSpec.describe Api::V1::Chapters::ChapterNotesController do
  routes { V1Api.routes }

  let(:pattern) do
    {
      id: Integer,
      section_id: nil,
      chapter_id: String,
      content: String,
    }
  end

  context 'when chapter note is present' do
    let(:chapter) { create :chapter, :with_note }

    it 'returns rendered record' do
      get :show, params: { chapter_id: chapter.to_param }, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end

  context 'when chapter note is not present' do
    let(:chapter) { create :chapter }

    it 'returns not found if record was not found' do
      get :show, params: { chapter_id: chapter.to_param }, format: :json

      expect(response.status).to eq 404
    end
  end
end
