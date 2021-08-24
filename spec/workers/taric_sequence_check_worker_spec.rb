describe TaricSequenceCheckWorker, type: :worker do
  before do
    allow(TariffSynchronizer::TaricSequenceChecker).to receive(:new).and_return(taric_sequence_checker)
    allow(TradeTariffBackend).to receive(:service).and_return(service)
  end

  let(:taric_sequence_checker) { instance_double(TariffSynchronizer::TaricSequenceChecker, perform: 'foo') }

  describe '#perform' do
    context 'when on the uk service' do
      let(:service) { 'uk' }

      it 'does not call perform on the instance of TaricSequenceChecker' do
        silence { described_class.new.perform }

        expect(taric_sequence_checker).not_to have_received(:perform)
      end
    end

    context 'when on the xi service' do
      let(:service) { 'xi' }

      it 'calls perform on the instance of TaricSequenceChecker' do
        silence { described_class.new.perform }

        expect(taric_sequence_checker).to have_received(:perform)
      end
    end
  end
end
