describe TradeTariffBackend::DataMigration do
  describe 'migrating up' do
    let(:measure) { create :measure }

    context 'migration applicable' do
      let(:migration) do
        TradeTariffBackend::DataMigration.new do
          up do
            applicable   { Measure.dataset.one? }
            apply        { Measure.dataset.destroy }
          end
        end
      end

      it 'executes migration' do
        measure

        expect { migration.up.apply }.to change(Measure, :count).from(1).to(0)
      end
    end

    context 'migration not applicable' do
      let(:migration) do
        TradeTariffBackend::DataMigration.new do
          up do
            applicable   { Measure.dataset.count == 42 }
            apply        { Measure.dataset.destroy }
          end
        end
      end

      it 'does not execute migration' do
        measure

        expect { migration.up.apply }.to change(Measure, :count).from(1).to(0)
      end
    end
  end

  describe 'migrating down' do
    let(:measure) { create :measure }

    context 'migration applicable' do
      let(:migration) do
        TradeTariffBackend::DataMigration.new do
          down do
            applicable   { Measure.dataset.one? }
            apply        { Measure.dataset.destroy }
          end
        end
      end

      it 'executes migration' do
        measure

        expect { migration.down.apply }.to change(Measure, :count).from(1).to(0)
      end
    end

    context 'migration not applicable' do
      let(:migration) do
        TradeTariffBackend::DataMigration.new do
          down do
            applicable   { Measure.dataset.count == 42 }
            apply        { Measure.dataset.destroy }
          end
        end
      end

      it 'does not execute migration' do
        measure

        expect { migration.down.apply }.to change(Measure, :count).from(1).to(0)
      end
    end
  end
end
