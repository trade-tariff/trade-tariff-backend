RSpec.describe 'Retired legacy note endpoints' do
  %w[/uk/admin/chapters/01/chapter_note.json /uk/admin/sections/1/section_note.json].each do |path|
    %i[get post patch delete].each do |method|
      it "returns not found for #{method.upcase} #{path}" do
        public_send(method, path, headers: request_headers(format: :json))

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
