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
