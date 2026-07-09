RSpec.describe Api::V1::SectionsController do
  describe 'GET #show' do
    let(:chapter) { create :chapter, :with_section }
    let(:section) { chapter.section }

    let(:pattern) do
      {
        id: Integer,
        position: Integer,
        title: String,
        numeral: String,
        chapter_from: String,
        chapter_to: String,
        chapters: Array,
        _response_info: Hash,
      }
    end

    context 'when record is present' do
      it 'returns api_response record' do
        get "/uk/api/sections/#{section.position}.json", headers: request_headers(format: :json)

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'when record is not present' do
      it 'returns not found if record was not found' do
        get "/uk/api/sections/#{section.position + 1}.json", headers: request_headers(format: :json)

        expect(response.status).to eq 404
      end
    end
  end

  describe 'GET #index' do
    let!(:first_chapter) { create :chapter, :with_section }
    let!(:second_chapter) { create :chapter, :with_section }
    let(:first_section) { first_chapter.section }
    let(:second_section) { second_chapter.section }

    let(:pattern) do
      [
        {
          id: Integer,
          section_note_id: nil,
          position: Integer,
          title: String,
          numeral: String,
          chapter_from: String,
          chapter_to: String,
          search_references_count: Integer,
        },
        {
          id: Integer,
          section_note_id: nil,
          position: Integer,
          title: String,
          numeral: String,
          chapter_from: String,
          chapter_to: String,
          search_references_count: Integer,
        },
      ]
    end

    it 'returns api_response records' do
      get '/uk/api/sections.json', headers: request_headers(format: :json)

      expect(response.body).to match_json_expression pattern
    end
  end
end
