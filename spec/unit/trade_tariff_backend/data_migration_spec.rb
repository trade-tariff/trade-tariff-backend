RSpec.describe TradeTariffBackend::DataMigration do
  describe 'migration definition' do
    describe '.desc' do
      let!(:example_migration) do
        TradeTariffBackend::DataMigration.new do
          desc 'example description'
        end
      end

      it 'sets a migration description' do
        expect(example_migration.desc).to eq 'example description'
      end
    end

    describe '.name' do
      let!(:example_migration) do
        TradeTariffBackend::DataMigration.new do
          name 'example name'
        end
      end

      it 'sets a migration name' do
        expect(example_migration.name).to eq 'example name'
      end
    end

    describe '.up' do
      let!(:example_migration) do
        TradeTariffBackend::DataMigration.new do
          up do
            applicable   { true }
            apply        {}
          end
        end
      end

      it 'instantiates migration Runner' do
        expect(example_migration.up).to be_kind_of TradeTariffBackend::DataMigration::Runner
      end

      it 'sets up runner with provided up block' do
        expect(example_migration.up.applicable?).to be_truthy
      end
    end

    describe '.down' do
      let!(:example_migration) do
        TradeTariffBackend::DataMigration.new do
          down do
            applicable   { true }
            apply        {}
          end
        end
      end

      it 'instantiates migration Runner' do
        expect(example_migration.down).to be_kind_of TradeTariffBackend::DataMigration::Runner
      end

      it 'sets up runner with provided up block' do
        expect(example_migration.down.applicable?).to be_truthy
      end
    end
  end

  describe '#can_rollup?' do
    let!(:example_migration) do
      TradeTariffBackend::DataMigration.new do
        up do
          applicable   { true }
          apply        {}
        end
      end
    end

    it 'delegates to up_runner' do
      expect(example_migration.can_rollup?).to be_truthy
    end
  end

  describe '#can_rolldown?' do
    let!(:example_migration) do
      TradeTariffBackend::DataMigration.new do
        down do
          applicable   { true }
          apply        {}
        end
      end
    end

    it 'delegates to down_runner' do
      expect(example_migration.can_rolldown?).to be_truthy
    end
  end

  describe '#up' do
    context 'runner undefined' do
      let!(:example_migration) do
        TradeTariffBackend::DataMigration.new
      end

      it 'returns NullRunner' do
        expect(example_migration.up).to be_kind_of TradeTariffBackend::DataMigration::NullRunner
      end
    end
  end

  describe '#down' do
    context 'runner undefined' do
      let!(:example_migration) do
        TradeTariffBackend::DataMigration.new
      end

      it 'returns NullRunner' do
        expect(example_migration.down).to be_kind_of TradeTariffBackend::DataMigration::NullRunner
      end
    end
  end
end
