require 'data_migrator'

RSpec.describe TaricUpdatesSynchronizerWorker, type: :worker do
  shared_examples_for 'a synchronizer worker that fires the updates applied event' do
    it 'instruments the tariff updates applied event for xi service' do
      expect(ActiveSupport::Notifications).to have_received(:instrument).with(
        TradeTariffBackend::TariffUpdateEventListener::TARIFF_UPDATES_APPLIED,
        hash_including(service: 'xi'),
      )
    end
  end

  describe '#perform' do
    subject(:perform) { described_class.new.perform }

    before do
      allow(TaricSynchronizer).to receive(:download)
      allow(TaricSynchronizer).to receive(:apply).and_return(changes_applied)
      allow(CdsSynchronizer).to receive(:download)
      allow(CdsSynchronizer).to receive(:apply).and_return(changes_applied)

      allow(TradeTariffBackend).to receive(:service).and_return(service)

      allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original
      allow(ActiveSupport::Notifications).to receive(:instrument).with(
        TradeTariffBackend::TariffUpdateEventListener::TARIFF_UPDATES_APPLIED,
        anything,
      )

      migrations_dir = Rails.root.join(file_fixture_path).join('data_migrations')
      allow(DataMigrator).to receive_messages(migrations_dir:, migrate_up!: true)

      allow(GoodsNomenclatures::TreeNode).to receive(:refresh!).and_call_original
    end

    let(:changes_applied) { true }

    context 'when on the xi service' do
      before { perform }

      let(:service) { 'xi' }

      it { expect(TaricSynchronizer).to have_received(:download) }
      it { expect(TaricSynchronizer).to have_received(:apply) }

      it { expect(CdsSynchronizer).not_to have_received(:download) }
      it { expect(CdsSynchronizer).not_to have_received(:apply) }

      it { expect(DataMigrator).not_to have_received(:migrate_up!) }

      it { expect(GoodsNomenclatures::TreeNode).to have_received(:refresh!) }

      it_behaves_like 'a synchronizer worker that fires the updates applied event'

      it 'passes the oldest pending date in the event payload' do
        expect(ActiveSupport::Notifications).to have_received(:instrument).with(
          TradeTariffBackend::TariffUpdateEventListener::TARIFF_UPDATES_APPLIED,
          hash_including(oldest_pending_date: Time.zone.today.iso8601),
        )
      end

      it { expect(described_class.jobs).to be_empty }

      context 'with reapply_data_migrations option' do
        subject(:perform) { described_class.new.perform(true) }

        it { expect(TaricSynchronizer).to have_received(:download) }
        it { expect(DataMigrator).to have_received(:migrate_up!).with(nil) }
      end

      context 'with no updates applied' do
        let(:changes_applied) { nil }

        it { expect(TaricSynchronizer).to have_received(:download) }
        it { expect(TaricSynchronizer).to have_received(:apply) }

        context 'with reapply_data_migrations option' do
          subject(:perform) { described_class.new.perform(true) }

          it { expect(TaricSynchronizer).to have_received(:download) }
          it { expect(DataMigrator).not_to have_received(:migrate_up!) }
        end
      end
    end

    context 'when a retriable download error is raised' do
      let(:service) { 'xi' }

      before do
        allow(TaricSynchronizer).to receive(:download)
          .and_raise(TariffSynchronizer::TariffUpdatesRequester::RetriableDownloadError, 'http://example/file')
      end

      context 'when retry budget remains' do
        it 'reschedules the job with an incremented retry count' do
          described_class.new.perform(false, 0)

          expect(described_class.jobs).to have_attributes length: 1
          expect(described_class.jobs.first).to include('args' => [false, 1])
        end
      end

      context 'when retry budget is exhausted' do
        it 'does not reschedule the job' do
          described_class.new.perform(false, described_class::DOWNLOAD_MAX_RETRIES)

          expect(described_class.jobs).to be_empty
        end
      end
    end
  end
end
