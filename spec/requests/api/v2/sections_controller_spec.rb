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
          create(:customs_tariff_section_note, :approved,
                 customs_tariff_update: older_update,
                 section_id: section.id,
                 content: 'Older approved section note')
          create(:customs_tariff_section_note,
                 customs_tariff_update: latest_update,
                 section_id: section.id,
                 content: 'Latest pending section note')
          create(:customs_tariff_section_note,
                 customs_tariff_update: failed_update,
                 section_id: section.id,
                 content: 'Failed update section note')
        end

        it 'returns the section note from the latest non-failed update' do
          api_get "/uk/api/sections/#{section.position}"

          expect(JSON.parse(response.body).dig('data', 'attributes', 'section_note')).to eq('Latest pending section note')
        end
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
    it_behaves_like 'a successful csv response' do
      let(:path) { '/uk/api/sections' }
      let(:expected_filename) { "uk-sections-#{Time.zone.today.iso8601}.csv" }

      before do
        create(
          :section,
          id: 18,
          position: 18,
          numeral: 'XVIII',
          title: 'Optical, photographic, cinematographic, measuring',
        )
      end
    end
  end
end
