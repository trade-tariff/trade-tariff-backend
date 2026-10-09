RSpec.describe 'search_references rake tasks' do
  describe 'search_references:import_fpo' do
    subject(:import_fpo) { Rake::Task['search_references:import_fpo'].invoke }

    after { Rake::Task['search_references:import_fpo'].reenable }

    before { allow(SearchReferences::FpoCsvImporter).to receive(:call) }

    it 'imports the default CSV' do
      import_fpo

      expect(SearchReferences::FpoCsvImporter).to have_received(:call)
        .with(Rails.root.join('data/fpo_extra_references.csv').to_s, dry_run: false, whodunnit: 'fpo_csv_import')
    end

    it 'imports the CSV given in CSV with DRY_RUN' do
      stub_const('ENV', ENV.to_h.merge('CSV' => '/tmp/refs.csv', 'DRY_RUN' => 'true'))

      import_fpo

      expect(SearchReferences::FpoCsvImporter).to have_received(:call).with('/tmp/refs.csv', dry_run: true, whodunnit: 'fpo_csv_import')
    end

    it 'passes WHODUNNIT to the importer' do
      stub_const('ENV', ENV.to_h.merge('WHODUNNIT' => 'jane@example.com'))

      import_fpo

      expect(SearchReferences::FpoCsvImporter).to have_received(:call)
        .with(anything, dry_run: false, whodunnit: 'jane@example.com')
    end

    it 'aborts in the XI service' do
      allow(TradeTariffBackend).to receive(:uk?).and_return(false)

      expect { import_fpo }.to raise_error(SystemExit).and output(/only in the UK service/).to_stderr
    end

    it 'has a default CSV that exists' do
      expect(Rails.root.join('data/fpo_extra_references.csv')).to exist
    end
  end

  describe 'search_references:backfill_destroy_versions' do
    subject(:backfill) { suppress_output { Rake::Task['search_references:backfill_destroy_versions'].invoke } }

    after { Rake::Task['search_references:backfill_destroy_versions'].reenable }

    let!(:orphan) { create(:search_reference, title: 'orphan') }
    let!(:destroyed) { create(:search_reference, title: 'destroyed') }
    let!(:existing) { create(:search_reference, title: 'existing') }

    let(:destroy_versions) { Version.where(item_type: 'SearchReference', event: 'destroy') }

    before do
      orphan.update(title: 'orphan updated')
      orphan.delete
      destroyed.destroy
    end

    it 'writes a destroy version for references removed without one' do
      expect { backfill }.to change(destroy_versions, :count).by(1)

      version = destroy_versions.where(item_id: orphan.id.to_s).first
      expect(version).to have_attributes(whodunnit: 'ClearInvalidSearchReferences (backfill)')
      expect(version.object['title']).to eq('orphan updated')
    end

    it 'dates the destroy version from the last known version, not today' do
      last_version = Version.where(item_type: 'SearchReference', item_id: orphan.id.to_s).order(Sequel.desc(:id)).first
      last_version.update(created_at: Time.zone.parse('2026-04-01 10:00'))

      backfill

      expect(destroy_versions.where(item_id: orphan.id.to_s).first.created_at).to eq(Time.zone.parse('2026-04-01 10:00'))
    end

    it 'lists the destroy version above the last version it shares a date with' do
      backfill

      latest = Version.most_recent_first.where(item_type: 'SearchReference', item_id: orphan.id.to_s).first
      expect(latest.event).to eq('destroy')
    end

    it 'leaves existing and already destroyed references alone' do
      backfill

      expect(destroy_versions.where(item_id: [existing.id.to_s, destroyed.id.to_s]).count).to eq(1)
    end

    it 'is idempotent' do
      task = Rake::Task['search_references:backfill_destroy_versions']
      suppress_output { task.invoke }
      task.reenable

      expect { suppress_output { task.invoke } }.not_to change(destroy_versions, :count)
    end

    it 'writes nothing with DRY_RUN' do
      stub_const('ENV', ENV.to_h.merge('DRY_RUN' => 'true'))

      expect { backfill }.not_to change(destroy_versions, :count)
    end
  end
end
