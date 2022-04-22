RSpec.describe Api::V2::ChaptersController do
  describe 'GET #index' do
    it_behaves_like 'a successful csv response' do
      let(:path) { '/chapters' }
      let(:expected_filename) { "uk-chapters-#{Time.zone.today.iso8601}.csv" }

      before do
        create(:chapter)
      end
    end
  end

  describe 'GET #chapters/:id/headings' do
    let(:heading) { create :heading, :with_chapter }
    let(:chapter) { heading.reload.chapter }

    let(:path) { "/chapters/#{chapter.short_code}/headings" }

    context 'when request asks for JSON format' do
      subject { make_request && response }

      let(:make_request) { get path }

      it_behaves_like 'a successful jsonapi response'
    end

    context 'when request asks for CSV format' do
      it_behaves_like 'a successful csv response'
    end
  end
end
