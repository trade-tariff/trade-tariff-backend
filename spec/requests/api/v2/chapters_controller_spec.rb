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

  describe 'GET #headings' do
    let(:heading) { create :heading, :with_chapter }
    let(:chapter) { heading.reload.chapter }

    let(:expected_filename) { "uk-chapter-#{chapter.short_code}-headings-#{Time.zone.today.iso8601}.csv" }

    it_behaves_like 'a successful csv response' do
      let(:path) { "/chapters/#{chapter.short_code}/headings" }
    end
  end
end
