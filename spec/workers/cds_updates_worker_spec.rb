RSpec.describe CdsUpdatesWorker, type: :worker do
  describe '#perform' do
    subject(:perform) { described_class.new.perform }

    before do
      allow($stdout).to receive(:write)

      allow(CdsSynchronizer).to receive(:download)
      allow(CdsSynchronizer).to receive(:apply)

      stub_const 'CdsUpdatesWorker::CUT_OFF_TIME', cut_off_time.strftime('%H:%M')
    end

    let(:cut_off_time) { 1.hour.from_now }

    context 'with todays file missing' do
      before do
        allow(CdsSynchronizer).to receive(:downloaded_todays_file?)
                                     .and_return(false)
      end

      context 'when before cut off time' do
        before { perform }

        it { expect(CdsSynchronizer).to have_received(:download) }
        it { expect(CdsSynchronizer).not_to have_received(:apply) }

        it { expect(described_class.jobs).to have_attributes length: 1 }

        it 'creates a later job to re-attempt download and processing' do
          expect(described_class.jobs.first).to \
            include 'at' => be_within(2)
                            .of(described_class::TRY_AGAIN_IN.from_now.to_f),
                    'args' => [true],
                    'retry' => false
        end
      end

      context 'when after cut off time' do
        before { perform }

        let(:cut_off_time) { 5.minutes.ago }

        it { expect(CdsSynchronizer).to have_received(:download) }
        it { expect(CdsSynchronizer).to have_received(:apply) }

        it { expect(described_class.jobs).to be_empty }
      end

      context 'when before cut off but check disabled' do
        before { described_class.new.perform(false) }

        it { expect(CdsSynchronizer).to have_received(:download) }
        it { expect(CdsSynchronizer).to have_received(:apply) }

        it { expect(described_class.jobs).to be_empty }
      end
    end

    context 'with todays file present' do
      before do
        allow(CdsSynchronizer).to receive(:downloaded_todays_file?)
                                     .and_return(true)

        perform
      end

      it { expect(CdsSynchronizer).to have_received(:download) }
      it { expect(CdsSynchronizer).to have_received(:apply) }

      it { expect(described_class.jobs).to be_empty }
    end
  end
end
