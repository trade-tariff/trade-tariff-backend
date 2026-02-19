require 'data_migrator'

RSpec.describe TaricUpdatesSynchronizerWorker, type: :worker do
  shared_examples_for 'a synchronizer worker that queues other workers' do
    it { expect(Sidekiq::Client).to have_received(:enqueue_in).with(5.minutes, ClearInvalidSearchReferences) }
    it { expect(Sidekiq::Client).to have_received(:enqueue_in).with(10.minutes, TreeIntegrityCheckWorker) }
    it { expect(Sidekiq::Client).to have_received(:enqueue_in).with(15.minutes, GreenLanesUpdatesWorker, Time.zone.today.iso8601) }
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

      it_behaves_like 'a synchronizer worker that queues other workers'

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
  end
end
