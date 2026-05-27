RSpec.describe Api::Admin::CustomsTariffUpdates::SectionNotesController do
  around { |example| TimeMachine.now { example.run } }

  describe 'GET #index' do
    let!(:approved_update) { create(:customs_tariff_update, :approved, validity_start_date: 1.month.ago) }
    let!(:pending_update)  { create(:customs_tariff_update, validity_start_date: Time.zone.today) }
    let!(:approved_note) do
      create(:customs_tariff_section_note, customs_tariff_update: approved_update, section_id: 1,
                                           content: 'Old content that is long enough to be text-diffed by the service version one')
    end
    let!(:pending_note) do
      create(:customs_tariff_section_note, customs_tariff_update: pending_update, section_id: 1,
                                           content: 'New content that is long enough to be text-diffed by the service version two')
    end

    it 'returns section notes with file_diff for changed content' do
      get "/uk/admin/customs_tariff_updates/#{pending_update.version}/section_notes.json",
          headers: request_headers(format: :json)

      expect(response.status).to eq(200)
      note = JSON.parse(response.body)['data'].find { |n| n.dig('attributes', 'section_id') == 1 }
      expect(note.dig('attributes', 'file_diff', 'changed_fields')).to include('content')
    end

    it 'returns file_diff as empty hash when content is identical' do
      pending_note.update(content: approved_note.content)

      get "/uk/admin/customs_tariff_updates/#{pending_update.version}/section_notes.json",
          headers: request_headers(format: :json)

      note = JSON.parse(response.body)['data'].find { |n| n.dig('attributes', 'section_id') == 1 }
      expect(note.dig('attributes', 'file_diff')).to eq({})
    end

    it 'returns file_diff as nil when section has no approved counterpart' do
      create(:customs_tariff_section_note, customs_tariff_update: pending_update, section_id: 5)

      get "/uk/admin/customs_tariff_updates/#{pending_update.version}/section_notes.json",
          headers: request_headers(format: :json)

      note = JSON.parse(response.body)['data'].find { |n| n.dig('attributes', 'section_id') == 5 }
      expect(note.dig('attributes', 'file_diff')).to be_nil
    end

    it 'returns empty data when the update has no notes' do
      update_with_no_notes = create(:customs_tariff_update, validity_start_date: 2.months.ago)

      get "/uk/admin/customs_tariff_updates/#{update_with_no_notes.version}/section_notes.json",
          headers: request_headers(format: :json)

      expect(JSON.parse(response.body)['data']).to be_empty
    end
  end

  describe 'GET #show' do
    let!(:update) { create(:customs_tariff_update) }
    let!(:note)   { create(:customs_tariff_section_note, customs_tariff_update: update) }

    it 'returns the note with a versions array' do
      get "/uk/admin/customs_tariff_updates/#{update.version}/section_notes/#{note.id}.json",
          headers: request_headers(format: :json)

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).dig('data', 'attributes', 'versions')).to be_an(Array)
    end
  end

  describe 'PATCH #update' do
    let!(:update) { create(:customs_tariff_update) }
    let!(:note)   { create(:customs_tariff_section_note, customs_tariff_update: update) }

    it 'updates the content' do
      patch "/uk/admin/customs_tariff_updates/#{update.version}/section_notes/#{note.id}.json",
            params: { data: { type: 'customs_tariff_section_note', attributes: { content: 'Updated content' } } },
            headers: request_headers(format: :json), as: :json

      expect(response.status).to eq(200)
      expect(note.reload.content).to eq('Updated content')
    end

    it 'returns 422 when the parent update is rejected' do
      update.update(status: CustomsTariffUpdate::REJECTED)

      patch "/uk/admin/customs_tariff_updates/#{update.version}/section_notes/#{note.id}.json",
            params: { data: { type: 'customs_tariff_section_note', attributes: { content: 'Updated' } } },
            headers: request_headers(format: :json), as: :json

      expect(response.status).to eq(422)
    end

    it 'creates a Version record on successful save' do
      expect {
        patch "/uk/admin/customs_tariff_updates/#{update.version}/section_notes/#{note.id}.json",
              params: { data: { type: 'customs_tariff_section_note', attributes: { content: 'Versioned content' } } },
              headers: request_headers(format: :json), as: :json
      }.to change { Version.where(item_type: 'CustomsTariffSectionNote', item_id: note.id.to_s).count }.by(1)
    end
  end
end
