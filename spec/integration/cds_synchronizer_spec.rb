RSpec.describe CdsSynchronizer do
  context 'for uk' do
    describe '#apply', :truncation do
      let!(:cds_update) do
        create :cds_update, :pending,
               filename: "tariff_dailyExtract_v1_#{example_date.strftime('%Y%m%d')}T123456.gzip",
               example_date: example_date
      end

      before do
        prepare_synchronizer_folders('cds')
        create_cds_file example_date
        allow(TradeTariffBackend).to receive(:service).and_return('uk')
      end

      after do
        purge_synchronizer_folders
      end

      context 'when everything is fine' do
        it 'applies missing updates' do
          described_class.apply
          expect(cds_update.reload).to be_applied
          expect(Measure::Operation.where(measure_sid: '20186262')).to be_present
        end
      end

      context 'when cds fails' do
        before do
          instance = instance_double(CdsImporter)
          allow(CdsImporter).to receive(:new).and_return(instance)
          allow(instance).to receive(:import).and_raise(CdsImporter::ImportException)
        end

        it 'marks cds update to be pending' do
          expect(cds_update).to be_pending
          expect { described_class.apply }.not_to raise_error
        end

        it 'marks cds update as failed' do
          expect { described_class.apply }.not_to raise_error
          expect(cds_update.reload).to be_failed
        end
      end

      context 'when elasticsearch is buggy' do
        before do
          entity_mapper = instance_double(CdsImporter::EntityMapper)
          allow(CdsImporter::EntityMapper).to receive(:new).and_return(entity_mapper)
          allow(entity_mapper).to receive(:build).and_raise(OpenSearch::Transport::Transport::SnifferTimeoutError)

          allow(TariffSynchronizer::CdsUpdate).to receive(:find).and_return(nil)
        end

        it 'stops syncing' do
          expect(cds_update.reload).not_to be_applied
        end

        it 'handles the error without crashing the sync process' do
          expect { described_class.apply }.not_to raise_error
        end
      end

      context 'when we have a timeout' do
        before do
          entity_mapper = instance_double(CdsImporter::EntityMapper)
          allow(CdsImporter::EntityMapper).to receive(:new).and_return(entity_mapper)
          allow(entity_mapper).to receive(:build).and_raise(Timeout::Error)

          allow(TariffSynchronizer::CdsUpdate).to receive(:find).and_return(nil)
        end

        it 'stops syncing' do
          expect(cds_update.reload).not_to be_applied
        end

        it 'handles the error without crashing the sync process' do
          expect { described_class.apply }.not_to raise_error
        end
      end
    end

    describe '.rollback' do
      let!(:update) { create :cds_update, :applied, filename: 'rollback.xml', issue_date: Time.zone.today }

      let :data_migrations do
        DataMigration.unrestrict_primary_key
        DataMigration.create filename: "#{Time.zone.now.strftime('%Y%m%d%H%M%S')}_today.rb"
        DataMigration.create filename: "#{2.days.ago.strftime('%Y%m%d%H%M%S')}_older.rb"
      end

      before do
        allow(TradeTariffBackend).to receive(:service).and_return('uk')
      end

      context 'when successful run' do
        let!(:measure_today) do
          create :measure, operation_date: Time.zone.today, filename: 'rollback.xml'
        end
        let!(:measure_older) do
          create :measure, operation_date: 2.days.ago.to_date, filename: '2_days_ago.xml'
        end

        before do
          data_migrations
          described_class.rollback(Time.zone.yesterday, keep: true)
        end

        it_with_refresh_materialized_view 'removes oplog rows with operation_date after the rollback date' do
          expect(Measure::Operation.where(measure_sid: measure_today.measure_sid)).to be_none
          expect(Measure::Operation.where(measure_sid: measure_older.measure_sid)).to be_present
        end

        it 'marks Cds updates as pending' do
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
        end

        it 'leaves Cds updates in applied state' do
          expect { described_class.rollback(Time.zone.yesterday, keep: true) }.to raise_error(StandardError)
          expect(update.reload).to be_applied
        end

        it "leaves both today's and the earlier data migration record" do
          expect { described_class.rollback(Time.zone.yesterday, keep: true) }.to raise_error(StandardError)
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

        it 'deletes Cds updates' do
          expect { update.reload }.to raise_error Sequel::Error
        end
      end

      context 'with date passed as string' do
        let!(:older_update) do
          create :cds_update, :applied, issue_date: 2.days.ago
        end

        before do
          described_class.rollback(Time.zone.yesterday)
        end

        it_with_refresh_materialized_view 'removes entries from oplog derived tables' do
          expect(Measure).to be_none
        end

        it 'deletes Cds updates' do
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
