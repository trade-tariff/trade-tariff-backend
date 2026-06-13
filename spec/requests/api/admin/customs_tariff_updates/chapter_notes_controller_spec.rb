RSpec.describe Api::Admin::CustomsTariffUpdates::ChapterNotesController do
  around { |example| TimeMachine.now { example.run } }

  describe 'GET #index' do
    let!(:approved_update) { create(:customs_tariff_update, :approved, validity_start_date: 1.month.ago) }
    let!(:pending_update)  { create(:customs_tariff_update, validity_start_date: Time.zone.today) }
    let!(:approved_note) do
      create(:customs_tariff_chapter_note, customs_tariff_update: approved_update, chapter_id: '01',
                                           content: 'Old chapter content that is long enough to text-diff properly')
    end
    let!(:pending_note) do
      create(:customs_tariff_chapter_note, customs_tariff_update: pending_update, chapter_id: '01',
                                           content: 'New chapter content that is long enough to text-diff properly')
    end

    it 'returns chapter notes with file_diff for changed content' do
      get "/uk/admin/customs_tariff_updates/#{pending_update.version}/chapter_notes.json",
          headers: request_headers(format: :json)

      expect(response.status).to eq(200)
      note = JSON.parse(response.body)['data'].find { |n| n.dig('attributes', 'chapter_id') == '01' }
      expect(note['id']).to eq('01')
      expect(note.dig('attributes', 'file_diff', 'changed_fields')).to include('content')
    end

    it 'returns file_diff as empty hash when content is identical' do
      pending_note.update(content: approved_note.content)

      get "/uk/admin/customs_tariff_updates/#{pending_update.version}/chapter_notes.json",
          headers: request_headers(format: :json)

      note = JSON.parse(response.body)['data'].find { |n| n.dig('attributes', 'chapter_id') == '01' }
      expect(note.dig('attributes', 'file_diff')).to eq({})
    end

    it 'returns file_diff as nil when chapter has no approved counterpart' do
      create(:customs_tariff_chapter_note, customs_tariff_update: pending_update, chapter_id: '50')

      get "/uk/admin/customs_tariff_updates/#{pending_update.version}/chapter_notes.json",
          headers: request_headers(format: :json)

      note = JSON.parse(response.body)['data'].find { |n| n.dig('attributes', 'chapter_id') == '50' }
      expect(note.dig('attributes', 'file_diff')).to be_nil
    end

    context 'with compare_version param' do
      let!(:compare_update) { create(:customs_tariff_update, :approved, validity_start_date: 3.months.ago) }
      let!(:target_update)  { create(:customs_tariff_update, validity_start_date: Time.zone.today) }

      before do
        create(:customs_tariff_chapter_note, customs_tariff_update: compare_update, chapter_id: '10',
                                             content: 'Compare chapter content long enough for text diffing here')
        create(:customs_tariff_chapter_note, customs_tariff_update: target_update, chapter_id: '10',
                                             content: 'Target chapter content long enough for text diffing here')
      end

      it 'diffs against the specified compare_version' do
        get "/uk/admin/customs_tariff_updates/#{target_update.version}/chapter_notes.json",
            params: { compare_version: compare_update.version },
            headers: request_headers(format: :json)

        expect(response.status).to eq(200)
        note = JSON.parse(response.body)['data'].find { |n| n.dig('attributes', 'chapter_id') == '10' }
        expect(note.dig('attributes', 'file_diff', 'changed_fields')).to include('content')
      end
    end

    context 'when the most recent preceding update is pending (not approved)' do
      # Uses chapter_id '99' to avoid collisions with outer let! notes (chapter_id '01').
      # previous_pending (5.days.ago) has a note for '99'; approved_update (1.month.ago) does not.
      # Old code: approved_notes_index finds approved_update → no note for '99' → file_diff = nil
      # New code: previous_update finds previous_pending → note found → file_diff has changed_fields
      let!(:previous_pending) { create(:customs_tariff_update, validity_start_date: 5.days.ago) }
      let!(:current_update)   { create(:customs_tariff_update, validity_start_date: 4.days.ago) }

      before do
        create(:customs_tariff_chapter_note, customs_tariff_update: previous_pending, chapter_id: '99',
                                             content: 'Previous chapter content long enough for text diffing here')
        create(:customs_tariff_chapter_note, customs_tariff_update: current_update, chapter_id: '99',
                                             content: 'Current chapter content long enough for text diffing here')
      end

      it 'uses the pending previous update as baseline, returning a diff instead of nil' do
        get "/uk/admin/customs_tariff_updates/#{current_update.version}/chapter_notes.json",
            headers: request_headers(format: :json)

        note = JSON.parse(response.body)['data'].find { |n| n.dig('attributes', 'chapter_id') == '99' }
        expect(note.dig('attributes', 'file_diff')).not_to be_nil
        expect(note.dig('attributes', 'file_diff', 'changed_fields')).to include('content')
      end
    end
  end

  describe 'GET #show' do
    let!(:update) { create(:customs_tariff_update) }
    let!(:note)   { create(:customs_tariff_chapter_note, customs_tariff_update: update) }

    it 'returns the note with a versions array' do
      get "/uk/admin/customs_tariff_updates/#{update.version}/chapter_notes/#{note.chapter_id}.json",
          headers: request_headers(format: :json)

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).dig('data', 'attributes', 'versions')).to be_an(Array)
    end

    context 'with compare_version param' do
      let!(:compare_update) { create(:customs_tariff_update, :approved, validity_start_date: 1.month.ago) }

      before do
        create(:customs_tariff_chapter_note, customs_tariff_update: compare_update,
                                             chapter_id: note.chapter_id,
                                             content: 'Old content long enough to trigger text diff in service')
        note.update(content: 'New content long enough to trigger text diff in service here')
      end

      it 'returns file_diff instead of versions' do
        get "/uk/admin/customs_tariff_updates/#{update.version}/chapter_notes/#{note.chapter_id}.json",
            params: { compare_version: compare_update.version },
            headers: request_headers(format: :json)

        attrs = JSON.parse(response.body).dig('data', 'attributes')
        expect(attrs['file_diff']).to be_a(Hash)
        expect(attrs['file_diff']['changed_fields']).to include('content')
        expect(attrs['versions']).to eq([])
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:update) { create(:customs_tariff_update) }
    let!(:note)   { create(:customs_tariff_chapter_note, customs_tariff_update: update) }

    it 'destroys the note and returns 204' do
      delete "/uk/admin/customs_tariff_updates/#{update.version}/chapter_notes/#{note.chapter_id}.json",
             headers: request_headers(format: :json)

      expect(response.status).to eq(204)
      expect(CustomsTariffChapterNote.where(id: note.id).first).to be_nil
    end

    it 'returns 422 and does not destroy when the parent update is rejected' do
      update.update(status: CustomsTariffUpdate::REJECTED)

      delete "/uk/admin/customs_tariff_updates/#{update.version}/chapter_notes/#{note.chapter_id}.json",
             headers: request_headers(format: :json)

      expect(response.status).to eq(422)
      expect(CustomsTariffChapterNote.where(id: note.id).first).not_to be_nil
    end

    it 'returns 404 when the note does not belong to the update' do
      other_update = create(:customs_tariff_update)

      delete "/uk/admin/customs_tariff_updates/#{other_update.version}/chapter_notes/#{note.chapter_id}.json",
             headers: request_headers(format: :json)

      expect(response.status).to eq(404)
    end
  end

  describe 'POST #create' do
    let!(:update) { create(:customs_tariff_update) }
    let(:chapter_id) { '03' }

    let(:make_request) do
      post "/uk/admin/customs_tariff_updates/#{update.version}/chapter_notes.json",
           params: { data: { type: 'customs_tariff_chapter_note', attributes: { chapter_id:, content: 'New chapter note content.' } } },
           headers: request_headers(format: :json), as: :json
    end

    it 'returns 201 and creates the record with correct attributes' do
      expect { make_request }.to change(CustomsTariffChapterNote, :count).by(1)
      expect(response.status).to eq(201)
      note = CustomsTariffChapterNote.order(Sequel.desc(:id)).first
      expect(note.chapter_id).to eq('03')
      expect(note.status).to eq(CustomsTariffChapterNote::PENDING)
      expect(note.validity_start_date).to eq(update.validity_start_date)
    end

    it 'returns 422 when the parent update is rejected' do
      update.update(status: CustomsTariffUpdate::REJECTED)
      expect { make_request }.not_to(change(CustomsTariffChapterNote, :count))
      expect(response.status).to eq(422)
    end

    it 'returns 422 on duplicate (update_version, chapter_id)' do
      create(:customs_tariff_chapter_note, customs_tariff_update: update, chapter_id:)
      expect { make_request }.not_to(change(CustomsTariffChapterNote, :count))
      expect(response.status).to eq(422)
    end
  end

  describe 'PATCH #update' do
    let!(:update) { create(:customs_tariff_update) }
    let!(:note)   { create(:customs_tariff_chapter_note, customs_tariff_update: update) }

    it 'updates the content' do
      patch "/uk/admin/customs_tariff_updates/#{update.version}/chapter_notes/#{note.chapter_id}.json",
            params: { data: { type: 'customs_tariff_chapter_note', attributes: { content: 'Updated content' } } },
            headers: request_headers(format: :json), as: :json

      expect(response.status).to eq(200)
      expect(note.reload.content).to eq('Updated content')
    end

    it 'updates when following the JSON:API id from the index response' do
      get "/uk/admin/customs_tariff_updates/#{update.version}/chapter_notes.json",
          headers: request_headers(format: :json)

      response_id = JSON.parse(response.body).dig('data', 0, 'id')

      patch "/uk/admin/customs_tariff_updates/#{update.version}/chapter_notes/#{response_id}.json",
            params: { data: { type: 'customs_tariff_chapter_note', attributes: { content: 'Updated via response id' } } },
            headers: request_headers(format: :json), as: :json

      expect(response.status).to eq(200)
      expect(note.reload.content).to eq('Updated via response id')
    end

    it 'returns 422 when the parent update is rejected' do
      update.update(status: CustomsTariffUpdate::REJECTED)

      patch "/uk/admin/customs_tariff_updates/#{update.version}/chapter_notes/#{note.chapter_id}.json",
            params: { data: { type: 'customs_tariff_chapter_note', attributes: { content: 'Updated' } } },
            headers: request_headers(format: :json), as: :json

      expect(response.status).to eq(422)
    end

    it 'creates a Version record on successful save' do
      expect {
        patch "/uk/admin/customs_tariff_updates/#{update.version}/chapter_notes/#{note.chapter_id}.json",
              params: { data: { type: 'customs_tariff_chapter_note', attributes: { content: 'Versioned' } } },
              headers: request_headers(format: :json), as: :json
      }.to change { Version.where(item_type: 'CustomsTariffChapterNote', item_id: note.id.to_s).count }.by(1)
    end
  end
end
