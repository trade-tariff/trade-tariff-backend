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

    context 'with compare_version param' do
      let!(:compare_update) do
        create(:customs_tariff_update, :approved, validity_start_date: 3.months.ago)
      end
      let!(:target_update) do
        create(:customs_tariff_update, validity_start_date: Time.zone.today)
      end

      before do
        create(:customs_tariff_section_note, customs_tariff_update: compare_update, section_id: 10,
                                             content: 'Compare section content that is long enough for text diffing here')
        create(:customs_tariff_section_note, customs_tariff_update: target_update, section_id: 10,
                                             content: 'Target section content that is long enough for text diffing here')
      end

      it 'diffs against the specified compare_version instead of latest approved' do
        get "/uk/admin/customs_tariff_updates/#{target_update.version}/section_notes.json",
            params: { compare_version: compare_update.version },
            headers: request_headers(format: :json)

        expect(response.status).to eq(200)
        note = JSON.parse(response.body)['data'].find { |n| n.dig('attributes', 'section_id') == 10 }
        expect(note.dig('attributes', 'file_diff', 'changed_fields')).to include('content')
      end

      it 'returns nil file_diff when section has no counterpart in the compare version' do
        create(:customs_tariff_section_note, customs_tariff_update: target_update, section_id: 20)

        get "/uk/admin/customs_tariff_updates/#{target_update.version}/section_notes.json",
            params: { compare_version: compare_update.version },
            headers: request_headers(format: :json)

        note = JSON.parse(response.body)['data'].find { |n| n.dig('attributes', 'section_id') == 20 }
        expect(note.dig('attributes', 'file_diff')).to be_nil
      end
    end
  end

  describe 'GET #show' do
    let!(:update) { create(:customs_tariff_update) }
    let!(:note)   { create(:customs_tariff_section_note, customs_tariff_update: update) }

    it 'returns the note with a versions array' do
      get "/uk/admin/customs_tariff_updates/#{update.version}/section_notes/#{note.section_id}.json",
          headers: request_headers(format: :json)

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).dig('data', 'attributes', 'versions')).to be_an(Array)
    end

    context 'with compare_version param' do
      let!(:compare_update) do
        create(:customs_tariff_update, :approved, validity_start_date: 1.month.ago)
      end

      context 'when a matching note exists in the compare version' do
        before do
          create(:customs_tariff_section_note,
                 customs_tariff_update: compare_update,
                 section_id: note.section_id,
                 content: 'Old content that is long enough to trigger text diff in the service here')
          note.update(content: 'New content that is long enough to trigger text diff in the service here')
        end

        it 'returns file_diff instead of versions' do
          get "/uk/admin/customs_tariff_updates/#{update.version}/section_notes/#{note.section_id}.json",
              params: { compare_version: compare_update.version },
              headers: request_headers(format: :json)

          expect(response.status).to eq(200)
          attrs = JSON.parse(response.body).dig('data', 'attributes')
          expect(attrs['file_diff']).to be_a(Hash)
          expect(attrs['file_diff']['changed_fields']).to include('content')
          expect(attrs['versions']).to eq([])
        end
      end

      context 'when the section has no counterpart in the compare version' do
        it 'returns nil file_diff' do
          other_update = create(:customs_tariff_update, validity_start_date: 2.months.ago)
          orphan_note = create(:customs_tariff_section_note,
                               customs_tariff_update: other_update,
                               section_id: 99)

          get "/uk/admin/customs_tariff_updates/#{other_update.version}/section_notes/#{orphan_note.section_id}.json",
              params: { compare_version: compare_update.version },
              headers: request_headers(format: :json)

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body).dig('data', 'attributes', 'file_diff')).to be_nil
        end
      end
    end
  end

  describe 'PATCH #update' do
    let!(:update) { create(:customs_tariff_update) }
    let!(:note)   { create(:customs_tariff_section_note, customs_tariff_update: update) }

    before do
      allow(CustomsTariffImporter::Instrumentation).to receive(:section_note_updated)
    end

    it 'updates the content' do
      patch "/uk/admin/customs_tariff_updates/#{update.version}/section_notes/#{note.section_id}.json",
            params: { data: { type: 'customs_tariff_section_note', attributes: { content: 'Updated content' } } },
            headers: request_headers({ 'X-Whodunnit' => 'operator-1' }, format: :json), as: :json

      expect(response.status).to eq(200)
      expect(note.reload.content).to eq('Updated content')
      expect(CustomsTariffImporter::Instrumentation).to have_received(:section_note_updated).with(
        version: update.version,
        section_id: note.section_id,
        note_id: note.id,
        whodunnit: 'operator-1',
      )
    end

    it 'returns 422 when the parent update is rejected' do
      update.update(status: CustomsTariffUpdate::REJECTED)

      patch "/uk/admin/customs_tariff_updates/#{update.version}/section_notes/#{note.section_id}.json",
            params: { data: { type: 'customs_tariff_section_note', attributes: { content: 'Updated' } } },
            headers: request_headers(format: :json), as: :json

      expect(response.status).to eq(422)
      expect(CustomsTariffImporter::Instrumentation).not_to have_received(:section_note_updated)
    end

    it 'creates a Version record on successful save' do
      expect {
        patch "/uk/admin/customs_tariff_updates/#{update.version}/section_notes/#{note.section_id}.json",
              params: { data: { type: 'customs_tariff_section_note', attributes: { content: 'Versioned content' } } },
              headers: request_headers(format: :json), as: :json
      }.to change { Version.where(item_type: 'CustomsTariffSectionNote', item_id: note.id.to_s).count }.by(1)
    end
  end

  describe 'DELETE #destroy' do
    let!(:update) { create(:customs_tariff_update) }
    let!(:note)   { create(:customs_tariff_section_note, customs_tariff_update: update) }

    it 'destroys the note and returns 204' do
      delete "/uk/admin/customs_tariff_updates/#{update.version}/section_notes/#{note.section_id}.json",
             headers: request_headers(format: :json)

      expect(response.status).to eq(204)
      expect(CustomsTariffSectionNote.where(id: note.id).first).to be_nil
    end

    it 'returns 422 and does not destroy when the parent update is rejected' do
      update.update(status: CustomsTariffUpdate::REJECTED)

      delete "/uk/admin/customs_tariff_updates/#{update.version}/section_notes/#{note.section_id}.json",
             headers: request_headers(format: :json)

      expect(response.status).to eq(422)
      expect(CustomsTariffSectionNote.where(id: note.id).first).not_to be_nil
    end

    it 'returns 404 when the note does not belong to the update' do
      other_update = create(:customs_tariff_update)

      delete "/uk/admin/customs_tariff_updates/#{other_update.version}/section_notes/#{note.section_id}.json",
             headers: request_headers(format: :json)

      expect(response.status).to eq(404)
    end
  end

  describe 'POST #create' do
    let!(:update) { create(:customs_tariff_update, validity_start_date: Date.new(2026, 3, 1)) }

    it 'creates a section note and returns 201' do
      post "/uk/admin/customs_tariff_updates/#{update.version}/section_notes.json",
           params: { data: { type: 'customs_tariff_section_note',
                             attributes: { section_id: 7, content: 'Manually added note content here' } } },
           headers: request_headers(format: :json), as: :json

      expect(response.status).to eq(201)
      attrs = JSON.parse(response.body).dig('data', 'attributes')
      expect(attrs['section_id']).to eq(7)
      expect(attrs['content']).to eq('Manually added note content here')
    end

    it 'sets status to pending and copies validity_start_date from the update' do
      post "/uk/admin/customs_tariff_updates/#{update.version}/section_notes.json",
           params: { data: { type: 'customs_tariff_section_note',
                             attributes: { section_id: 8, content: 'Some note content here' } } },
           headers: request_headers(format: :json), as: :json

      note = CustomsTariffSectionNote.where(
        customs_tariff_update_version: update.version, section_id: 8,
      ).first
      expect(note.status).to eq(CustomsTariffSectionNote::PENDING)
      expect(note.validity_start_date).to eq(Date.new(2026, 3, 1))
    end

    it 'returns 422 when the parent update is rejected' do
      update.update(status: CustomsTariffUpdate::REJECTED)

      post "/uk/admin/customs_tariff_updates/#{update.version}/section_notes.json",
           params: { data: { type: 'customs_tariff_section_note',
                             attributes: { section_id: 7, content: 'Some content' } } },
           headers: request_headers(format: :json), as: :json

      expect(response.status).to eq(422)
    end
  end
end
