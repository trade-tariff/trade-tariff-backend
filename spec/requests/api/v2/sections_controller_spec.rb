RSpec.describe Api::V2::SectionsController, :v2 do
  describe 'GET #show' do
    let!(:section) { create(:section) }
    let!(:legacy_note) { create(:section_note, section_id: section.id, content: 'Legacy section note') }
    let!(:customs_tariff_update) { create(:customs_tariff_update, :approved) }

    before do
      create(:customs_tariff_section_note, :approved,
             customs_tariff_update:,
             section_id: section.id,
             content: 'Imported section note')
    end

    context 'when customs tariff notes are promoted' do
      before do
        allow(TradeTariffBackend).to receive(:promote_customs_tariff_notes?).and_return(true)
      end

      it 'returns the imported section note' do
        api_get "/uk/api/sections/#{section.position}"

        expect(JSON.parse(response.body).dig('data', 'attributes', 'section_note')).to eq('Imported section note')
      end
    end

    context 'when customs tariff notes are not promoted' do
      before do
        allow(TradeTariffBackend).to receive(:promote_customs_tariff_notes?).and_return(false)
      end

      it 'returns the legacy section note' do
        api_get "/uk/api/sections/#{section.position}"

        expect(JSON.parse(response.body).dig('data', 'attributes', 'section_note')).to eq(legacy_note.content)
      end
    end
  end

  describe 'GET #index' do
    let!(:section) do
      create(
        :section,
        id: 18,
        position: 18,
        numeral: 'XVIII',
        title: 'Optical, photographic, cinematographic, measuring',
      )
    end

    it 'returns only requested sparse fields for section resources' do
      api_get '/uk/api/sections', params: { fields: { section: 'title' } }

      attributes = JSON.parse(response.body).fetch('data').first.fetch('attributes')

      expect(attributes).to eq('title' => section.title)
    end

    it 'does not eager load chapter data when sparse fields exclude chapter-derived fields' do
      allow(Section).to receive(:eager).and_call_original

      api_get '/uk/api/sections', params: { fields: { section: 'title' } }

      expect(Section).not_to have_received(:eager)
    end

    it 'does not query chapter or note tables when sparse fields exclude those attributes' do
      section

      sql = []
      subscriber = ActiveSupport::Notifications.subscribe(/sql\.sequel/) do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        sql << event.payload[:sql].to_s
      end

      begin
        api_get '/uk/api/sections', params: { fields: { section: 'title' } }
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end

      expect(response).to have_http_status(:ok)
      forbidden_sql = sql.grep(/chapters|chapter_notes|section_notes/i)
      expect(forbidden_sql).to be_empty
    end

    it 'still eager loads attribute dependencies when include is empty and chapter-derived attributes are returned' do
      allow(Section).to receive(:eager).and_call_original

      api_get '/uk/api/sections', params: { include: '' }

      chapter_note_association = TradeTariffBackend.promote_customs_tariff_notes? ? :customs_tariff_chapter_note : :chapter_note
      section_note_association = TradeTariffBackend.promote_customs_tariff_notes? ? :customs_tariff_section_note : :section_note

      expect(Section)
        .to have_received(:eager)
        .with({ chapters: [chapter_note_association] }, section_note_association)
    end

    it 'returns a bad request for unsupported include paths' do
      api_get '/uk/api/sections', params: { include: 'unknown_relationship' }

      expect(response).to have_http_status(:bad_request)
    end

    it_behaves_like 'a successful csv response' do
      let(:path) { '/uk/api/sections' }
      let(:expected_filename) { "uk-sections-#{Time.zone.today.iso8601}.csv" }
    end
  end
end
