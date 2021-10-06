RSpec.describe TradeTariffBackend::DataMigrator do
  before do
    described_class.migrations = []
    allow(TradeTariffBackend).to receive(:data_migration_path).and_return(
      File.join(Rails.root, 'spec', 'fixtures', 'data_migration_samples'),
    )
  end

  describe '#migration' do
    it 'defines a new migration' do
      described_class.migration do
        desc 'Foo'
      end

      expect(described_class.migrations.first.desc).to eq 'Foo'
    end
  end

  describe '#migrations' do
    context 'some migrations defined' do
      it 'returns migration array' do
        example_migration = described_class.migration do
          desc 'Foo'
        end

        expect(described_class.migrations).to include example_migration
      end
    end

    context 'no migrations defined' do
      it 'returns empty array' do
        expect(described_class.migrations).to eq []
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
      described_class.migrate
      TradeTariffBackend::DataMigration::LogEntry.last.destroy
    end

    it 'applies all pending migrations' do
      expect { described_class.migrate }.to change(TradeTariffBackend::DataMigration::LogEntry, :count).by(1)
    end

    it 'does not apply applied migrations' do
      expect(described_class.pending_migration_files).not_to include(applied_migration)
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
      allow(described_class).to receive(:pending_migration_files).and_return(
        [applied_migration, other_applied_migration],
      )
      described_class.migrate
    end

    it 'rolls back last applied migration' do
      expect { described_class.rollback }.to change(TradeTariffBackend::DataMigration::LogEntry, :count).by(-1)
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
      expect(described_class.pending_migration_files).not_to include(migration)
    end
  end

  describe '#redo' do
    before do
      allow(described_class).to receive(:rollback).and_return(nil)
      allow(described_class).to receive(:migrate).and_return(nil)
    end

    it 'rolls back last applied migration' do
      expect_any_instance_of(described_class).to receive(:rollback)
      described_class.redo
    end

    it 'migrates rolled back migration' do
      expect_any_instance_of(described_class).to receive(:migrate)
      described_class.redo
    end
  end
end
