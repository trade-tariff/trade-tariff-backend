RSpec.describe Api::Admin::SectionsController do
  describe 'GET #index' do
    it 'returns sections' do
      create(:section, :with_chapter, :with_note)

      get '/uk/admin/sections.json', headers: request_headers(format: :json)

      expect(response.body).to match_json_expression(data: [Hash])
    end
  end

  describe 'GET #show' do
    it 'returns a section' do
      section = create(:section, :with_chapter, :with_note)

      get "/uk/admin/sections/#{section.position}.json", headers: request_headers(format: :json)

      expect(response.body).to match_json_expression(data: Hash, included: Array)
    end
  end
end
