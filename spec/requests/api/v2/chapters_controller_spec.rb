RSpec.describe Api::V2::ChaptersController do
  describe 'GET #index' do
    it_behaves_like 'a successful csv response', '/sections' do
      before do
        create(:chapter)
      end
    end
  end
end
