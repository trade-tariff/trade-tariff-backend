RSpec.describe TaricSynchronizer do
  context 'for xi' do
    describe '#apply', :truncation do
      let!(:taric_update) { create :taric_update, :pending, example_date: }

      before do
        prepare_synchronizer_folders
        create_taric_file example_date
        allow(TradeTariffBackend).to receive(:service).and_return('xi')
      end

      after do
        purge_synchronizer_folders
      end

      context 'when everything is fine' do
        it 'applies missing updates' do
          described_class.apply
          expect(taric_update.reload).to be_applied
        end
      end

      context 'when taric fails' do
        before do
          instance = instance_double(TaricImporter)
          allow(TaricImporter).to receive(:new).and_return(instance)
          allow(instance).to receive(:import).and_raise(TaricImporter::ImportException)
        end

        it 'marks taric update to be pending' do
          expect(taric_update).to be_pending
          rescuing { described_class.apply }
        end

        it 'marks taric update as failed' do
          rescuing { described_class.apply }
          expect(taric_update.reload).to be_failed
        end
      end

      context 'when elasticsearch is buggy' do
        before do
          instance = instance_double(TaricImporter::Transaction)
          allow(TaricImporter::Transaction).to receive(:new).and_return(instance)

          allow(instance).to receive(
            :persist,
          ).and_raise OpenSearch::Transport::Transport::SnifferTimeoutError

          allow(TariffSynchronizer::TaricUpdate).to receive(:find).and_return(nil)
        end

        it 'stops syncing' do
          expect(taric_update.reload).not_to be_applied
        end

        it 'stops syncing and roll back' do
          expect { described_class.apply }.to raise_error Sequel::Rollback
        end
      end

      context 'when we have a timeout' do
        before do
          instance = instance_double(TaricImporter::Transaction)
          allow(TaricImporter::Transaction).to receive(:new).and_return(instance)

          allow(instance).to receive(
            :persist,
          ).and_raise Timeout::Error

          allow(TariffSynchronizer::TaricUpdate).to receive(:find).and_return(nil)
        end

        it 'stops syncing' do
          expect(taric_update.reload).not_to be_applied
        end

        it 'stops syncing and roll back' do
          expect { described_class.apply }.to raise_error Sequel::Rollback
        end
      end
    end

    describe '.rollback' do
      let!(:update) { create :taric_update, :applied, issue_date: Time.zone.today }

      let :data_migrations do
        DataMigration.unrestrict_primary_key
        DataMigration.create filename: "#{Time.zone.now.strftime('%Y%m%d%H%M%S')}_today.rb"
        DataMigration.create filename: "#{2.days.ago.strftime('%Y%m%d%H%M%S')}_older.rb"
      end

      before do
        allow(TradeTariffBackend).to receive(:service).and_return('xi')
      end

      context 'when successful run' do
        before do
          data_migrations
          described_class.rollback(Time.zone.yesterday, keep: true)
        end

        it_with_refresh_materialized_view 'removes entries from oplog tables' do
          expect(Measure).to be_none
        end

        it 'marks Taric updates as pending' do
          expect(update.reload).to be_pending
        end

        it 'removes only todays data migration record' do
          expect(DataMigration.count).to be 1
        end
      end

      context 'when encounters an exception' do
        before do
          data_migrations

          allow(Measure).to receive(:operation_klass).and_raise(StandardError)

          rescuing { described_class.rollback(Time.zone.yesterday, keep: true) }
        end

        it 'leaves Taric updates in applid state' do
          expect(update.reload).to be_applied
        end

        it 'leaves both todays and the earlier data migration record' do
          expect(DataMigration.count).to be 2
        end
      end

      context 'when forced to redownload by default' do
        before do
          described_class.rollback(Time.zone.yesterday)
        end

        it_with_refresh_materialized_view 'removes entries from oplog derived tables' do
          expect(Measure).to be_none
        end

        it 'deletes Taric updates' do
          expect { update.reload }.to raise_error Sequel::Error
        end
      end

      context 'with date passed as string' do
        let!(:older_update) do
          create :taric_update, :applied, issue_date: 2.days.ago
        end

        before do
          described_class.rollback(Time.zone.yesterday)
        end

        it_with_refresh_materialized_view 'removes entries from oplog derived tables' do
          expect(Measure).to be_none
        end

        it 'deletes Taric updates' do
          expect { update.reload }.to raise_error Sequel::Error
        end

        it 'does not remove earlier updates (casts date as string to date)' do
          expect { older_update.reload }.not_to raise_error
        end
      end
    end
  end

  def example_date
    @example_date ||= Time.zone.today
  end
end
