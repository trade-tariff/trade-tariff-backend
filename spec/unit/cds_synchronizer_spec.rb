RSpec.describe CdsSynchronizer do
  describe '.downloaded_todays_file?' do
    before do
      allow(TariffSynchronizer::CdsUpdate).to receive(:downloaded_todays_file?).and_return(true)
    end

    it 'calls through to CdsUpdate#downloaded_todays_file?' do
      described_class.downloaded_todays_file?

      expect(TariffSynchronizer::CdsUpdate).to have_received(:downloaded_todays_file?)
    end
  end

  describe '.apply' do
    let(:applied_update) { create(:cds_update, :applied, example_date: Time.zone.yesterday) }
    let(:pending_update) { create(:cds_update, :pending, example_date: Time.zone.today) }

    context 'when the sequence of updates is not correct' do
      before do
        applied_date = Time.zone.yesterday
        pending_date = applied_date + 2.days

        create :cds_update, :applied, example_date: applied_date, filename: "tariff_dailyExtract_v1_#{applied_date.strftime('%Y%m%d')}T123456.gzip"

        create :cds_update, example_date: pending_date, filename: "tariff_dailyExtract_v1_#{pending_date.strftime('%Y%m%d')}T123456.gzip"
      end

      # rubocop:disable RSpec/MultipleExpectations
      it 'raises wrong sequence error and notifies Slack app' do
        allow(SlackNotifierService).to receive(:new).and_call_original

        expect { described_class.apply }.to raise_error(BaseSynchronizer::FailedUpdatesError)

        expect(SlackNotifierService).to have_received(:new)
      end
      # rubocop:enable RSpec/MultipleExpectations
    end

    context 'when reindex_all_indexes arg is not set' do
      subject(:apply) { described_class.apply }

      before do
        applied_update
        pending_update

        allow(Sidekiq::Client).to receive(:enqueue)
      end

      it 'does not kick off the ClearCacheWorker' do
        allow(TariffSynchronizer::BaseUpdateImporter).to receive(:perform)

        apply

        expect(Sidekiq::Client).not_to have_received(:enqueue).with(ClearCacheWorker)
      end
    end

    context 'when reindex_all_indexes arg is false' do
      subject(:apply) { described_class.apply(reindex_all_indexes: false) }

      before do
        applied_update
        pending_update

        allow(Sidekiq::Client).to receive(:enqueue)
      end

      it 'does not kick off the ClearCacheWorker' do
        allow(TariffSynchronizer::BaseUpdateImporter).to receive(:perform)

        apply

        expect(Sidekiq::Client).not_to have_received(:enqueue).with(ClearCacheWorker)
      end
    end

    context 'when reindex_all_indexes arg is true' do
      subject(:apply) { described_class.apply(reindex_all_indexes: true) }

      before do
        applied_update
        pending_update

        allow(Sidekiq::Client).to receive(:enqueue)
        allow(TariffSynchronizer::BaseUpdateImporter).to receive(:perform)

        allow(TariffSynchronizer::BaseUpdate).to receive(:pending_or_failed).and_return([])
      end

      it 'kicks off the ClearCacheWorker' do
        apply

        expect(Sidekiq::Client).to have_received(:enqueue).with(ClearCacheWorker)
      end
    end

    context 'with failed updates present' do
      before { create :taric_update, :failed }

      context 'when reindex_all_indexes arg is true' do
        subject(:apply) { described_class.apply(reindex_all_indexes: true) }

        it 'does not kick off the ClearCacheWorker' do
          allow(Sidekiq::Client).to receive(:enqueue)
          allow(TariffSynchronizer::BaseUpdateImporter).to receive(:perform)

          apply
        rescue StandardError
          expect(Sidekiq::Client).not_to have_received(:enqueue).with(ClearCacheWorker)
        end
      end
    end
  end
end
