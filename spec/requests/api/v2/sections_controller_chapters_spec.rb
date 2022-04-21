RSpec.describe Api::V2::Sections do
  describe 'GET #chapters' do
    let(:section) { create(:section, :with_chapter) }

    it_behaves_like 'a successful csv response' do
      let(:path) { "/sections/#{section.position}/chapters" }
    end
  end
end
