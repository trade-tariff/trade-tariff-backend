RSpec.describe Api::V2::Sections, :v2 do
  describe 'GET #chapters' do
    let(:section) { create(:section, :with_chapter) }

    it_behaves_like 'a successful csv response' do
      let(:path) { "/api/v2/sections/#{section.position}/chapters" }
      let(:expected_filename) { "uk-sections-#{section.position}-chapters-#{Time.zone.today.iso8601}.csv" }
    end
  end
end
