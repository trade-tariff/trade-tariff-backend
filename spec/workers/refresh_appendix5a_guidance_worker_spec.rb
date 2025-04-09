RSpec.describe RefreshAppendix5aGuidanceWorker, type: :worker do
  let(:worker) { described_class.new }

  describe '#perform' do
    include_context 'with a stubbed appendix 5a guidance s3 bucket'

    before do
      allow(Appendix5aPopulatorService).to receive(:new).and_call_original
      allow(Appendix5aMailer).to receive_message_chain(:appendix5a_notify_message, :deliver_now)
    end

    it 'calls the service' do
      worker.perform

      expect(Appendix5aPopulatorService).to have_received(:new)
    end
  end
end
