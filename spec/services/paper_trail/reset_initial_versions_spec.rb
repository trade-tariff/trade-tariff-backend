RSpec.describe PaperTrail::ResetInitialVersions do
  describe '#call' do
    around do |example|
      Rails.application.eager_load!
      travel_to(Time.zone.parse('2026-04-14 12:00:00')) { example.run }
    end

    it 'truncates existing versions and recreates one create snapshot per tracked record', :aggregate_failures do
      note = create(:section_note, content: 'before')
      note.update(content: 'after')
      config = create(:admin_configuration, name: 'reset_test_config')
      create(:description_intercept, term: 'boots')
      create(:goods_nomenclature_intercept)
      create(:goods_nomenclature_label)
      create(:goods_nomenclature_self_text)
      create(:search_reference)

      Version.create(
        item_type: 'GhostRecord',
        item_id: '123',
        event: 'update',
        object: Sequel.pg_jsonb_wrap('ghost' => true),
        whodunnit: 'user-1',
        created_at: 2.days.ago,
      )

      expect(Version.where(event: 'update').count).to be > 0

      described_class.new.call

      expect(Version.count).to eq(Sequel::Plugins::HasPaperTrail.tracked_models.sum(&:count))
      expect(Version.select_map(:event).uniq).to eq(%w[create])
      expect(Version.where(item_type: 'GhostRecord').count).to eq(0)

      note_version = Version.where(item_type: 'SectionNote', item_id: note.id.to_s).first
      expect(note_version.object['content']).to eq('after')

      config_version = Version.where(item_type: 'AdminConfiguration', item_id: config.name).first
      expect(config_version).not_to be_nil
    end

    it 'uses the current time when the tracked record has no timestamps' do
      note = create(:section_note)

      described_class.new.call

      version = Version.where(item_type: 'SectionNote', item_id: note.id.to_s).first
      expect(version.created_at).to eq(Time.zone.parse('2026-04-14 12:00:00'))
    end
  end
end
