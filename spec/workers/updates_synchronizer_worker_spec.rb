require 'data_migrator'

RSpec.describe UpdatesSynchronizerWorker, type: :worker do
  shared_examples_for 'a synchronizer worker that queues other workers' do
    it { expect(Sidekiq::Client).to have_received(:enqueue).with(ClearCacheWorker) }
    it { expect(Sidekiq::Client).to have_received(:enqueue).with(ClearInvalidSearchReferences) }
    it { expect(Sidekiq::Client).to have_received(:enqueue).with(GenerateMaterializedPathsWorker) }
    it { expect(Sidekiq::Client).to have_received(:enqueue).with(GenerateGoodsNomenclaturesCsvReportWorker) }
  end

  describe '#perform' do
    subject(:perform) { described_class.new.perform }

    before do
      allow(TariffSynchronizer).to receive(:download)
      allow(TariffSynchronizer).to receive(:apply).and_return(changes_applied)
      allow(TariffSynchronizer).to receive(:download_cds)
      allow(TariffSynchronizer).to receive(:apply_cds).and_return(changes_applied)

      allow(TradeTariffBackend).to receive(:service).and_return(service)

      allow(Sidekiq::Client).to receive(:enqueue)

      migrations_dir = Rails.root.join(file_fixture_path).join('data_migrations')
      allow(DataMigrator).to receive(:migrations_dir).and_return(migrations_dir)
      allow(DataMigrator).to receive(:migrate_up!).and_return(true)

      allow(GoodsNomenclatures::TreeNode).to receive(:refresh!).and_call_original
    end

    let(:changes_applied) { true }

    context 'when on the xi service' do
      before { perform }

      let(:service) { 'xi' }

      it { expect(TariffSynchronizer).to have_received(:download) }
      it { expect(TariffSynchronizer).to have_received(:apply) }

      it { expect(TariffSynchronizer).not_to have_received(:download_cds) }
      it { expect(TariffSynchronizer).not_to have_received(:apply_cds) }

      it { expect(DataMigrator).not_to have_received(:migrate_up!) }

      it { expect(GoodsNomenclatures::TreeNode).to have_received(:refresh!) }

      it_behaves_like 'a synchronizer worker that queues other workers'

      it { expect(described_class.jobs).to be_empty }

      context 'with reapply_data_migrations option' do
        subject(:perform) { described_class.new.perform(true, true) }

        it { expect(TariffSynchronizer).to have_received(:download) }
        it { expect(DataMigrator).to have_received(:migrate_up!).with(nil) }
      end

      context 'with no updates applied' do
        let(:changes_applied) { nil }

        it { expect(TariffSynchronizer).to have_received(:download) }
        it { expect(TariffSynchronizer).to have_received(:apply) }
        it { expect(Sidekiq::Client).not_to have_received(:enqueue) }

        context 'with reapply_data_migrations option' do
          subject(:perform) { described_class.new.perform(true, true) }

          it { expect(TariffSynchronizer).to have_received(:download) }
          it { expect(DataMigrator).not_to have_received(:migrate_up!) }
        end
      end
    end

    context 'when on the uk service' do
      before do
        stub_const 'UpdatesSynchronizerWorker::CUT_OFF_TIME',
                   cut_off_time.strftime('%H:%M')

        allow(SlackNotifierService).to receive(:call)
      end

      let(:service) { 'uk' }
      let(:cut_off_time) { 1.hour.from_now }

      context 'with todays file missing' do
        before do
          allow(TariffSynchronizer).to receive(:downloaded_todays_file_for_cds?)
                                       .and_return(false)

          perform
        end

        context 'when before cut off time' do
          it { expect(TariffSynchronizer).to have_received(:download_cds) }
          it { expect(TariffSynchronizer).not_to have_received(:apply_cds) }

          it { expect(TariffSynchronizer).not_to have_received(:download) }
          it { expect(TariffSynchronizer).not_to have_received(:apply) }

          it { expect(Sidekiq::Client).not_to have_received(:enqueue) }
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

          it { expect(TariffSynchronizer).to have_received(:download_cds) }
          it { expect(TariffSynchronizer).to have_received(:apply_cds) }

          it { expect(TariffSynchronizer).not_to have_received(:download) }
          it { expect(TariffSynchronizer).not_to have_received(:apply) }

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

          it { expect(TariffSynchronizer).to have_received(:download_cds) }
          it { expect(TariffSynchronizer).to have_received(:apply_cds) }

          it { expect(TariffSynchronizer).not_to have_received(:download) }
          it { expect(TariffSynchronizer).not_to have_received(:apply) }

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
          allow(TariffSynchronizer).to receive(:downloaded_todays_file_for_cds?)
                                       .and_return(true)

          perform
        end

        it { expect(TariffSynchronizer).to have_received(:download_cds) }
        it { expect(TariffSynchronizer).to have_received(:apply_cds) }

        it { expect(TariffSynchronizer).not_to have_received(:download) }
        it { expect(TariffSynchronizer).not_to have_received(:apply) }

        it { expect(DataMigrator).not_to have_received(:migrate_up!) }

        it_behaves_like 'a synchronizer worker that queues other workers'

        it { expect(described_class.jobs).to be_empty }

        it 'does not notify Slack ETL channel' do
          expect(SlackNotifierService).not_to have_received(:call)
        end

        context 'with reapply_data_migrations option' do
          subject(:perform) { described_class.new.perform(true, true) }

          it { expect(TariffSynchronizer).to have_received(:download_cds) }
          it { expect(DataMigrator).to have_received(:migrate_up!).with(nil) }
        end

        context 'with no updates applied' do
          let(:changes_applied) { nil }

          it { expect(TariffSynchronizer).to have_received(:download_cds) }
          it { expect(TariffSynchronizer).to have_received(:apply_cds) }
          it { expect(Sidekiq::Client).not_to have_received(:enqueue) }

          context 'with reapply_data_migrations option' do
            subject(:perform) { described_class.new.perform(true, true) }

            it { expect(TariffSynchronizer).to have_received(:download_cds) }
            it { expect(DataMigrator).not_to have_received(:migrate_up!) }
          end
        end
      end

      context 'when ListDownloadFailedError is raised it creates a retry job' do
        before do
          allow(TariffSynchronizer).to receive(:download_cds).and_raise TariffSynchronizer::CdsUpdateDownloader::ListDownloadFailedError

          perform
        end

        it { expect(described_class.jobs).to have_attributes length: 1 }
      end
    end
  end
end
