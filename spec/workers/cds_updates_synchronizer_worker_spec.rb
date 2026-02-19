require 'data_migrator'

RSpec.describe CdsUpdatesSynchronizerWorker, type: :worker do
  shared_examples_for 'a synchronizer worker that queues other workers' do
    it { expect(Sidekiq::Client).to have_received(:enqueue_in).with(5.minutes, ClearInvalidSearchReferences) }
    it { expect(Sidekiq::Client).to have_received(:enqueue_in).with(11.minutes, PopulateChangesTableWorker) }
    it { expect(Sidekiq::Client).to have_received(:enqueue_in).with(12.minutes, PopulateTariffChangesWorker) }
    it { expect(Sidekiq::Client).to have_received(:enqueue_in).with(5.minutes, ClearCacheWorker) }
  end

  describe '#perform' do
    subject(:perform) { described_class.new.perform }

    before do
      allow(TaricSynchronizer).to receive(:download)
      allow(TaricSynchronizer).to receive(:apply).and_return(changes_applied)
      allow(CdsSynchronizer).to receive(:download)
      allow(CdsSynchronizer).to receive(:apply).and_return(changes_applied)

      allow(TradeTariffBackend).to receive(:service).and_return(service)

      allow(Sidekiq::Client).to receive(:enqueue)
      allow(Sidekiq::Client).to receive(:enqueue_in)

      migrations_dir = Rails.root.join(file_fixture_path).join('data_migrations')
      allow(DataMigrator).to receive_messages(migrations_dir:, migrate_up!: true)

      allow(GoodsNomenclatures::TreeNode).to receive(:refresh!).and_call_original
      allow(GoodsNomenclatureChangeAccumulator).to receive(:flush!)
      stub_const 'CdsUpdatesSynchronizerWorker::CUT_OFF_TIME',
                 cut_off_time.strftime('%H:%M')

      allow(SlackNotifierService).to receive(:call)
    end

    let(:changes_applied) { true }
    let(:service) { 'uk' }
    let(:cut_off_time) { 1.hour.from_now }

    context 'with todays file missing' do
      before do
        allow(TariffSynchronizer::CdsUpdate).to receive(:downloaded_todays_file?).and_return(false)

        perform
      end

      context 'when before cut off time' do
        it { expect(CdsSynchronizer).to have_received(:download) }
        it { expect(CdsSynchronizer).not_to have_received(:apply) }

        it { expect(TaricSynchronizer).not_to have_received(:download) }
        it { expect(TaricSynchronizer).not_to have_received(:apply) }

        it { expect(described_class.jobs).to have_attributes length: 1 }

        it 'creates a later job to re-attempt download and processing' do
          expect(described_class.jobs.first).to \
            include 'at' => be_within(2)
                            .of(described_class::TRY_AGAIN_IN.from_now.to_f),
                    'args' => [true],
                    'retry' => false
        end

        context 'with reapply_data_migrations option' do
          subject(:perform) { described_class.new.perform(true, true) }

          it { expect(DataMigrator).not_to have_received(:migrate_up!) }
        end

        it 'does not notify Slack ETL channel' do
          expect(SlackNotifierService).not_to have_received(:call)
        end
      end

      context 'when after cut off time' do
        let(:cut_off_time) { 5.minutes.ago }

        it { expect(CdsSynchronizer).to have_received(:download) }
        it { expect(CdsSynchronizer).to have_received(:apply) }

        it { expect(TaricSynchronizer).not_to have_received(:download) }
        it { expect(TaricSynchronizer).not_to have_received(:apply) }

        it { expect(GoodsNomenclatures::TreeNode).to have_received(:refresh!) }

        it_behaves_like 'a synchronizer worker that queues other workers'

        it { expect(described_class.jobs).to be_empty }

        context 'with reapply_data_migrations option' do
          subject(:perform) { described_class.new.perform(true, true) }

          it { expect(DataMigrator).to have_received(:migrate_up!).with(nil) }
        end

        it 'notifies Slack ETL channel' do
          expect(SlackNotifierService).to have_received(:call).with(/CDS file missing/)
        end
      end

      context 'when before cut off but check disabled' do
        subject(:perform) { described_class.new.perform(false) }

        it { expect(CdsSynchronizer).to have_received(:download) }
        it { expect(CdsSynchronizer).to have_received(:apply) }

        it { expect(TaricSynchronizer).not_to have_received(:download) }
        it { expect(TaricSynchronizer).not_to have_received(:apply) }

        it { expect(GoodsNomenclatures::TreeNode).to have_received(:refresh!) }

        it_behaves_like 'a synchronizer worker that queues other workers'

        it { expect(described_class.jobs).to be_empty }

        context 'with reapply_data_migrations option' do
          subject(:perform) { described_class.new.perform(false, true) }

          it { expect(DataMigrator).to have_received(:migrate_up!).with(nil) }
        end

        it 'does not notify Slack ETL channel' do
          expect(SlackNotifierService).not_to have_received(:call)
        end
      end
    end

    context 'with todays file present' do
      before do
        allow(TariffSynchronizer::CdsUpdate).to receive(:downloaded_todays_file?)
                                     .and_return(true)

        perform
      end

      it { expect(CdsSynchronizer).to have_received(:download) }
      it { expect(CdsSynchronizer).to have_received(:apply) }

      it { expect(TaricSynchronizer).not_to have_received(:download) }
      it { expect(TaricSynchronizer).not_to have_received(:apply) }

      it { expect(DataMigrator).not_to have_received(:migrate_up!) }

      it_behaves_like 'a synchronizer worker that queues other workers'

      it { expect(described_class.jobs).to be_empty }

      it 'does not notify Slack ETL channel' do
        expect(SlackNotifierService).not_to have_received(:call)
      end

      context 'with reapply_data_migrations option' do
        subject(:perform) { described_class.new.perform(true, true) }

        it { expect(CdsSynchronizer).to have_received(:download) }
        it { expect(DataMigrator).to have_received(:migrate_up!).with(nil) }
      end

      context 'with no updates applied' do
        let(:changes_applied) { nil }

        it { expect(CdsSynchronizer).to have_received(:download) }
        it { expect(CdsSynchronizer).to have_received(:apply) }

        context 'with reapply_data_migrations option' do
          subject(:perform) { described_class.new.perform(true, true) }

          it { expect(CdsSynchronizer).to have_received(:download) }
          it { expect(DataMigrator).not_to have_received(:migrate_up!) }
        end
      end
    end

    context 'when ListDownloadFailedError is raised it creates a retry job' do
      before do
        allow(CdsSynchronizer).to receive(:download).and_raise TariffSynchronizer::CdsUpdateDownloader::ListDownloadFailedError

        perform
      end

      it { expect(described_class.jobs).to have_attributes length: 1 }
    end
  end
end
