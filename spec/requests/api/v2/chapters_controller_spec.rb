RSpec.describe Api::V2::ChaptersController do
  describe 'GET #index' do
    subject(:do_request) { make_request && response }

    before do
      create(:chapter)
    end

    context 'when using the mime suffix to configure the mime type' do
      let(:make_request) { get '/chapters.csv' }

      it_behaves_like 'a successful csv response'
    end

    context 'when using Accept header to configure the mime type' do
      let(:make_request) { get '/chapters', headers: { 'ACCEPT' => 'text/csv' } }

      it_behaves_like 'a successful csv response'
    end
  end
end
