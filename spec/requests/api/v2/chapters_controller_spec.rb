RSpec.describe Api::V2::ChaptersController, :v2 do
  let(:now) { Time.zone.today }
  let(:expires_at) { now.end_of_day }

  before do
    allow(Rails.cache).to receive(:fetch).and_call_original
  end

  describe 'GET #index' do
    it 'caches the serialized chapters' do
      get '/api/v2/chapters'

      expect(Rails.cache)
        .to have_received(:fetch)
        .with(
          "_chapters-#{now.iso8601}/v2",
          expires_at:,
        )
    end

    it_behaves_like 'a successful csv response' do
      let(:path) { '/api/v2/chapters' }
      let(:expected_filename) { "uk-chapters-#{Time.zone.today.iso8601}.csv" }

      before do
        create(:chapter)
      end
    end
  end

  describe 'GET #show' do
    let(:chapter) { create :chapter, :with_section }

    it 'caches the serialized chapters' do
      get "/api/v2/chapters/#{chapter.short_code}"

      expect(Rails.cache)
        .to have_received(:fetch)
        .with(
          "_chapter-#{chapter.short_code}-#{now.iso8601}/v2",
          expires_at:,
        )
    end
  end

  describe 'GET #changes' do
    let(:chapter) { create :chapter, :with_section }

    it 'caches the serialized chapter changes' do
      get changes_api_chapter_path(chapter)

      expect(Rails.cache)
        .to have_received(:fetch)
        .with(
          "_chapter-#{chapter.short_code}-#{now.iso8601}/changes-v2",
          expires_at:,
        )
    end
  end

  describe 'GET #headings' do
    let(:heading) { create :heading, :with_chapter }
    let(:chapter) { heading.reload.chapter }

    let(:expected_filename) { "uk-chapter-#{chapter.short_code}-headings-#{Time.zone.today.iso8601}.csv" }

    it_behaves_like 'a successful csv response' do
      let(:path) { "/api/v2/chapters/#{chapter.short_code}/headings" }
    end
  end
end
