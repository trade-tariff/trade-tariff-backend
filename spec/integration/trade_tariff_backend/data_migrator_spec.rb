RSpec.describe TradeTariffBackend::DataMigrator do
  before do
    allow(TradeTariffBackend).to receive(:data_migration_path).and_return(
      File.join(Rails.root, 'spec', 'fixtures', 'data_migration_samples'),
    )
    described_class.migrations = []
  end

  describe '#migrate' do
    context 'successful run' do
      before do
        allow(described_class).to receive(:pending_migration_files).and_return(
          [File.join(Rails.root, 'spec', 'fixtures', 'data_migration_samples', '1_migrate.rb')],
        )
      end

      it 'executes pending migrations' do
        described_class.migrate

        expect(Language.count).to eq 1
      end
    end

    context 'run with errors' do
      before do
        allow(described_class).to receive(:pending_migration_files).and_return(
          [File.join(Rails.root, 'spec', 'fixtures', 'data_migration_samples', '2_migrate_with_errors.rb')],
        )
      end

      it 'executes migrations in transactions' do
        allow(Language).to receive(:restrict_primary_key).and_raise(ArgumentError.new)

        rescuing { described_class.migrate }

        expect(Language.count).to eq 0
      end
    end
  end

  describe '#rollback' do
    context 'successful run' do
      before do
        allow(described_class).to receive(:pending_migration_files).and_return(
          [File.join(Rails.root, 'spec', 'fixtures', 'data_migration_samples', '3_rollback.rb')],
        )
        described_class.migrate
      end

      it 'rolls back applied migration' do
        described_class.rollback

        expect(Language.count).to eq 0
      end
    end

    context 'run with errors' do
      before do
        allow(described_class).to receive(:pending_migration_files).and_return(
          [File.join(Rails.root, 'spec', 'fixtures', 'data_migration_samples', '4_rollback_with_errors.rb')],
        )
        described_class.migrate
      end

      it 'executes migrations in transactions' do
        allow(Language).to receive(:restrict_primary_key).and_raise(StandardError)

        rescuing { described_class.rollback }

        expect(Language.count).to eq 1
      end
    end
  end
end
