RSpec.describe UpdatesSynchronizerWorker, type: :worker do
  describe '#perform' do
    subject(:perform) { described_class.new.perform }

    before do
      allow($stdout).to receive(:write)

      allow(TariffSynchronizer).to receive(:download)
      allow(TariffSynchronizer).to receive(:apply)
      allow(TariffSynchronizer).to receive(:download_cds)
      allow(TariffSynchronizer).to receive(:apply_cds)

      allow(TradeTariffBackend).to receive(:service).and_return(service)
    end

    context 'when on the xi service' do
      before { perform }

      let(:service) { 'xi' }

      it { expect(TariffSynchronizer).to have_received(:download) }
      it { expect(TariffSynchronizer).to have_received(:apply).with(reindex_all_indexes: true) }

      it { expect(TariffSynchronizer).not_to have_received(:download_cds) }
      it { expect(TariffSynchronizer).not_to have_received(:apply_cds) }

      it { expect(described_class.jobs).to be_empty }
    end

    context 'when on the uk service' do
      before do
        stub_const 'UpdatesSynchronizerWorker::CUT_OFF_TIME',
                   cut_off_time.strftime('%H:%M')
      end

      let(:service) { 'uk' }
      let(:cut_off_time) { 1.hour.from_now }

      context 'with todays file missing' do
        before do
          allow(TariffSynchronizer).to receive(:downloaded_todays_file_for_cds?)
                                       .and_return(false)
        end

        context 'when before cut off time' do
          before { perform }

          it { expect(TariffSynchronizer).to have_received(:download_cds) }
          it { expect(TariffSynchronizer).not_to have_received(:apply_cds) }

          it { expect(TariffSynchronizer).not_to have_received(:download) }
          it { expect(TariffSynchronizer).not_to have_received(:apply) }

          it { expect(described_class.jobs).to have_attributes length: 1 }

          it 'creates a later job to re-attempt download and processing' do
            expect(described_class.jobs.first).to \
              include 'at' => be_within(2).of(20.minutes.from_now.to_f),
                      'args' => [true],
                      'retry' => false
          end
        end

        context 'when after cut off time' do
          before { perform }

          let(:cut_off_time) { 5.minutes.ago }

          it { expect(TariffSynchronizer).to have_received(:download_cds) }
          it { expect(TariffSynchronizer).to have_received(:apply_cds) }

          it { expect(TariffSynchronizer).not_to have_received(:download) }
          it { expect(TariffSynchronizer).not_to have_received(:apply) }

          it { expect(described_class.jobs).to be_empty }
        end

        context 'when before cut off but check disabled' do
          before { described_class.new.perform(false) }

          it { expect(TariffSynchronizer).to have_received(:download_cds) }
          it { expect(TariffSynchronizer).to have_received(:apply_cds) }

          it { expect(TariffSynchronizer).not_to have_received(:download) }
          it { expect(TariffSynchronizer).not_to have_received(:apply) }

          it { expect(described_class.jobs).to be_empty }
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

        it { expect(described_class.jobs).to be_empty }
      end
    end
  end
end
