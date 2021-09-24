RSpec.describe TradeTariffBackend::DataMigrator do
  before do
    TradeTariffBackend::DataMigrator.migrations = []
    allow(TradeTariffBackend).to receive(:data_migration_path).and_return(
      File.join(Rails.root, 'spec', 'fixtures', 'data_migration_samples'),
    )
  end

  describe '#migration' do
    it 'defines a new migration' do
      TradeTariffBackend::DataMigrator.migration do
        desc 'Foo'
      end

      expect(TradeTariffBackend::DataMigrator.migrations.first.desc).to eq 'Foo'
    end
  end

  describe '#migrations' do
    context 'some migrations defined' do
      it 'returns migration array' do
        example_migration = TradeTariffBackend::DataMigrator.migration do
          desc 'Foo'
        end

        expect(TradeTariffBackend::DataMigrator.migrations).to include example_migration
      end
    end

    context 'no migrations defined' do
      it 'returns empty array' do
        expect(TradeTariffBackend::DataMigrator.migrations).to eq []
      end
    end
  end

  describe '#migrate' do
    let(:migration) do
      File.join(Rails.root, 'spec', 'fixtures', 'data_migration_samples', '3_not_applied.rb')
    end

    let(:applied_migration) do
      File.join(Rails.root, 'spec', 'fixtures', 'data_migration_samples', '1_applied.rb')
    end

    before do
      TradeTariffBackend::DataMigrator.migrate
      TradeTariffBackend::DataMigration::LogEntry.last.destroy
    end

    it 'applies all pending migrations' do
      expect { TradeTariffBackend::DataMigrator.migrate }.to change(TradeTariffBackend::DataMigration::LogEntry, :count).by(1)
    end

    it 'does not apply applied migrations' do
      expect(TradeTariffBackend::DataMigrator.pending_migration_files).not_to include(applied_migration)
    end
  end

  describe '#rollback' do
    let(:applied_migration) do
      File.join(Rails.root, 'spec', 'fixtures', 'data_migration_samples', '1_applied.rb')
    end

    let(:other_applied_migration) do
      File.join(Rails.root, 'spec', 'fixtures', 'data_migration_samples', '2_applied.rb')
    end

    let(:migration) do
      File.join(Rails.root, 'spec', 'fixtures', 'data_migration_samples', '3_not_applied.rb')
    end

    before do
      allow(TradeTariffBackend::DataMigrator).to receive(:pending_migration_files).and_return(
        [applied_migration, other_applied_migration],
      )
      TradeTariffBackend::DataMigrator.migrate
    end

    it 'rolls back last applied migration' do
      expect { TradeTariffBackend::DataMigrator.rollback }.to change(TradeTariffBackend::DataMigration::LogEntry, :count).by(-1)
      expect(
        TradeTariffBackend::DataMigration::LogEntry.where(filename: other_applied_migration).last,
      ).to be_nil
    end

    it 'does not rollback two applied migrations' do
      expect(
        TradeTariffBackend::DataMigration::LogEntry.where(filename: applied_migration).last,
      ).not_to be_nil
    end

    it 'does not rollback non applied migrations' do
      expect(TradeTariffBackend::DataMigrator.pending_migration_files).not_to include(migration)
    end
  end

  describe '#redo' do
    before do
      allow(TradeTariffBackend::DataMigrator).to receive(:rollback).and_return(nil)
      allow(TradeTariffBackend::DataMigrator).to receive(:migrate).and_return(nil)
    end

    it 'rolls back last applied migration' do
      expect_any_instance_of(TradeTariffBackend::DataMigrator).to receive(:rollback)
      TradeTariffBackend::DataMigrator.redo
    end

    it 'migrates rolled back migration' do
      expect_any_instance_of(TradeTariffBackend::DataMigrator).to receive(:migrate)
      TradeTariffBackend::DataMigrator.redo
    end
  end
end
