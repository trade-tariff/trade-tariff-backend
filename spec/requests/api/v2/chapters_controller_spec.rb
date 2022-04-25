RSpec.describe Api::V2::ChaptersController do
  describe 'GET #index' do
    it_behaves_like 'a successful csv response' do
      let(:path) { '/chapters' }
      let(:expected_filename) { "chapters-#{Time.zone.today.iso8601}.csv" }

      before do
        create(:chapter)
      end
    end
  end
end
