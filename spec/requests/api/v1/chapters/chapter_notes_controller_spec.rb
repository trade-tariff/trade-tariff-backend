RSpec.describe Api::V1::Chapters::ChapterNotesController do
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

    it 'returns api_response record' do
      get "/uk/api/chapters/#{chapter.to_param}/chapter_note.json", headers: request_headers(format: :json)

      expect(response.body).to match_json_expression pattern
    end
  end

  context 'when chapter note is not present' do
    let(:chapter) { create :chapter }

    it 'returns not found if record was not found' do
      get "/uk/api/chapters/#{chapter.to_param}/chapter_note.json", headers: request_headers(format: :json)

      expect(response.status).to eq 404
    end
  end
end
