RSpec.describe Api::V2::ChaptersController do
  describe 'GET #index' do
    subject(:do_request) { make_request && response }

    let(:make_request) { get '/chapters.csv' }

    before do
      create(:chapter)
    end

    it_behaves_like 'a successful csv response'
  end
end
