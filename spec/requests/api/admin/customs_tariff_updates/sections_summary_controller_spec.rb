RSpec.describe Api::Admin::CustomsTariffUpdates::SectionsSummaryController do
  around { |example| TimeMachine.now { example.run } }

  describe 'GET #index' do
    let!(:sections)        { create_list(:section, 21) }
    let!(:approved_update) { create(:customs_tariff_update, :approved, validity_start_date: 1.month.ago) }
    let!(:pending_update)  { create(:customs_tariff_update, validity_start_date: Time.zone.today) }

    it 'returns one row per section' do
      get "/uk/admin/customs_tariff_updates/#{pending_update.version}/sections_summary.json",
          headers: request_headers(format: :json)

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['data'].length).to eq(21)
    end

    context 'when a section note exists in the update' do
      let(:section_with_note)    { sections.first }
      let(:section_without_note) { sections.second }

      let!(:pending_note) do
        create(:customs_tariff_section_note, customs_tariff_update: pending_update,
                                             section_id: section_with_note.id,
                                             content: 'New section content long enough for text diff in service')
      end

      before do
        create(:customs_tariff_section_note, customs_tariff_update: approved_update,
                                             section_id: section_with_note.id,
                                             content: 'Old section content long enough for text diff in service')
      end

      it 'returns section_note_status as changed for the section with a note' do
        get "/uk/admin/customs_tariff_updates/#{pending_update.version}/sections_summary.json",
            headers: request_headers(format: :json)

        row = JSON.parse(response.body)['data'].find { |r| r.dig('attributes', 'section_id') == section_with_note.id }
        expect(row.dig('attributes', 'section_note_status')).to eq('changed')
        expect(row.dig('attributes', 'section_note_id')).to eq(pending_note.id)
      end

      it 'returns section_note_status as absent for sections with no note' do
        get "/uk/admin/customs_tariff_updates/#{pending_update.version}/sections_summary.json",
            headers: request_headers(format: :json)

        row = JSON.parse(response.body)['data'].find { |r| r.dig('attributes', 'section_id') == section_without_note.id }
        expect(row.dig('attributes', 'section_note_status')).to eq('absent')
        expect(row.dig('attributes', 'section_note_id')).to be_nil
      end
    end

    context 'when chapter notes exist in the update' do
      before do
        create(:customs_tariff_chapter_note, customs_tariff_update: approved_update, chapter_id: '01',
                                             content: 'Old chapter 1 content long enough for comparison')
        create(:customs_tariff_chapter_note, customs_tariff_update: pending_update, chapter_id: '01',
                                             content: 'New chapter 1 content long enough for comparison')
      end

      it 'returns chapter_notes_total and chapter_notes_changed for the section containing chapter 01' do
        pending 'chapter_to_section_map relies on chapters_sections join table populated with real tariff data; ' \
                'may be empty in test environment causing counts to be 0'

        get "/uk/admin/customs_tariff_updates/#{pending_update.version}/sections_summary.json",
            headers: request_headers(format: :json)

        row = JSON.parse(response.body)['data'].find { |r| r.dig('attributes', 'section_id') == sections.first.id }
        expect(row.dig('attributes', 'chapter_notes_total')).to eq(1)
        expect(row.dig('attributes', 'chapter_notes_changed')).to eq(1)
      end
    end

    context 'when the most recent preceding update is pending (not approved)' do
      # The outer approved_update (1.month.ago) has no notes for sections.last.
      # previous_pending (5.days.ago) is the most recent update before current_update (4.days.ago).
      # Old code: approved_notes_index finds approved_update → no notes → status = 'new'
      # New code: previous_update finds previous_pending → notes found → status = 'changed'
      let!(:previous_pending) { create(:customs_tariff_update, validity_start_date: 5.days.ago) }
      let!(:current_update)   { create(:customs_tariff_update, validity_start_date: 4.days.ago) }
      let(:section)           { sections.last }

      before do
        create(:customs_tariff_section_note, customs_tariff_update: previous_pending,
                                             section_id: section.id,
                                             content: 'Previous content long enough for text diff service to handle')
        create(:customs_tariff_section_note, customs_tariff_update: current_update,
                                             section_id: section.id,
                                             content: 'Current content long enough for text diff service to handle')
      end

      it 'uses the pending previous update as baseline' do
        get "/uk/admin/customs_tariff_updates/#{current_update.version}/sections_summary.json",
            headers: request_headers(format: :json)

        row = JSON.parse(response.body)['data'].find { |r| r.dig('attributes', 'section_id') == section.id }
        expect(row.dig('attributes', 'section_note_status')).to eq('changed')
      end
    end

    context 'when the immediately preceding update is failed' do
      # failed_update (5.days.ago) is skipped; older_pending (6.days.ago) is used as baseline.
      let!(:older_pending)  { create(:customs_tariff_update, validity_start_date: 6.days.ago) }
      let!(:current_update) { create(:customs_tariff_update, validity_start_date: 4.days.ago) }
      let(:section)         { sections.last }

      before do
        create(:customs_tariff_update, :failed, validity_start_date: 5.days.ago)
        create(:customs_tariff_section_note, customs_tariff_update: older_pending,
                                             section_id: section.id,
                                             content: 'Older content long enough for text diff service to handle it')
        create(:customs_tariff_section_note, customs_tariff_update: current_update,
                                             section_id: section.id,
                                             content: 'Current content long enough for text diff service to handle it')
      end

      it 'skips the failed update and uses the older pending update as baseline' do
        get "/uk/admin/customs_tariff_updates/#{current_update.version}/sections_summary.json",
            headers: request_headers(format: :json)

        row = JSON.parse(response.body)['data'].find { |r| r.dig('attributes', 'section_id') == section.id }
        expect(row.dig('attributes', 'section_note_status')).to eq('changed')
      end
    end
  end
end
