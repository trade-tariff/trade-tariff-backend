RSpec.describe Api::Admin::ChaptersController do
  describe 'GET #index' do
    it 'returns chapters' do
      create(:chapter, :with_note)

      get '/uk/admin/chapters.json', headers: request_headers(format: :json)

      expect(response.body).to match_json_expression(data: [Hash])
    end
  end

  describe 'GET #show' do
    it 'returns a chapter' do
      chapter = create(:chapter, :with_description, :with_headings, :with_note, :with_section)

      get "/uk/admin/chapters/#{chapter.short_code}.json", headers: request_headers(format: :json)

      expect(response.body).to match_json_expression(data: Hash, included: Array)
    end
  end
end
