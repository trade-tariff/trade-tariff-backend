RSpec.describe Api::V2::ChaptersController, :v2 do
  let(:now) { Time.zone.today }
  let(:expires_at) { now.end_of_day }

  before do
    allow(Rails.cache).to receive(:fetch).and_call_original
  end

  describe 'GET #index' do
    it 'caches the serialized chapters' do
      api_get '/uk/api/chapters'

      expect(Rails.cache)
        .to have_received(:fetch)
        .with(
          "_chapters-#{now.iso8601}/v2",
          expires_at:,
        )
    end

    it_behaves_like 'a successful csv response' do
      let(:path) { '/uk/api/chapters' }
      let(:expected_filename) { "uk-chapters-#{Time.zone.today.iso8601}.csv" }

      before do
        create(:chapter)
      end
    end
  end

  describe 'GET #show' do
    let(:chapter) { create :chapter, :with_section }

    it 'caches the serialized chapters' do
      api_get "/uk/api/chapters/#{chapter.short_code}"

      expect(Rails.cache)
        .to have_received(:fetch)
        .with(
          "_chapter-#{chapter.short_code}-#{now.iso8601}/v2",
          expires_at:,
        )
    end

    context 'when customs tariff notes are promoted' do
      let!(:customs_tariff_update) { create(:customs_tariff_update, :approved) }

      before do
        Rails.cache.clear
        create(:chapter_note, chapter_id: chapter.short_code, content: 'Legacy chapter note')
        create(:customs_tariff_chapter_note, :approved,
               customs_tariff_update:,
               chapter_id: chapter.short_code,
               content: 'Imported chapter note')
        allow(TradeTariffBackend).to receive(:promote_customs_tariff_notes?).and_return(true)
      end

      it 'returns the imported chapter note' do
        api_get "/uk/api/chapters/#{chapter.short_code}"

        expect(JSON.parse(response.body).dig('data', 'attributes', 'chapter_note')).to eq('Imported chapter note')
      end

      context 'when a newer non-failed update exists' do
        let!(:customs_tariff_update) do
          create(:customs_tariff_update, :approved,
                 version: '1.29',
                 validity_start_date: 2.months.ago.to_date)
        end
        let!(:older_update) do
          create(:customs_tariff_update, :approved,
                 version: '1.30',
                 validity_start_date: 1.month.ago.to_date)
        end
        let!(:latest_update) do
          create(:customs_tariff_update,
                 version: '1.31',
                 validity_start_date: Time.zone.today)
        end
        let!(:failed_update) do
          create(:customs_tariff_update, :failed,
                 version: '1.32',
                 validity_start_date: Time.zone.today)
        end

        before do
          Rails.cache.clear
          create(:customs_tariff_chapter_note, :approved,
                 customs_tariff_update: older_update,
                 chapter_id: chapter.short_code,
                 content: 'Older approved chapter note')
          create(:customs_tariff_chapter_note,
                 customs_tariff_update: latest_update,
                 chapter_id: chapter.short_code,
                 content: 'Latest pending chapter note')
          create(:customs_tariff_chapter_note,
                 customs_tariff_update: failed_update,
                 chapter_id: chapter.short_code,
                 content: 'Failed update chapter note')
        end

        it 'returns the chapter note from the latest non-failed update' do
          api_get "/uk/api/chapters/#{chapter.short_code}"

          expect(JSON.parse(response.body).dig('data', 'attributes', 'chapter_note')).to eq('Latest pending chapter note')
        end
      end
    end

    context 'when customs tariff notes are not promoted' do
      let!(:legacy_note) { create(:chapter_note, chapter_id: chapter.short_code, content: 'Legacy chapter note') }
      let!(:customs_tariff_update) { create(:customs_tariff_update, :approved) }

      before do
        Rails.cache.clear
        create(:customs_tariff_chapter_note, :approved,
               customs_tariff_update:,
               chapter_id: chapter.short_code,
               content: 'Imported chapter note')
        allow(TradeTariffBackend).to receive(:promote_customs_tariff_notes?).and_return(false)
      end

      it 'returns the legacy chapter note' do
        api_get "/uk/api/chapters/#{chapter.short_code}"

        expect(JSON.parse(response.body).dig('data', 'attributes', 'chapter_note')).to eq(legacy_note.content)
      end
    end
  end

  describe 'GET #changes' do
    let(:chapter) { create :chapter, :with_section }

    it 'caches the serialized chapter changes' do
      api_get changes_api_chapter_path(chapter)

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
      let(:path) { "/uk/api/chapters/#{chapter.short_code}/headings" }
    end
  end
end
