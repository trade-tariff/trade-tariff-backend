RSpec.describe RefreshAppendix5aGuidanceWorker, type: :worker do
  let(:worker) { described_class.new }
  let(:service) { instance_double(Appendix5aPopulatorService, call: true) }

  describe '#perform' do
    include_context 'with a stubbed appendix 5a guidance s3 bucket'

    before do
      allow(Appendix5aPopulatorService).to receive(:new).and_return(service)
    end

    it 'calls the service' do
      worker.perform

      expect(Appendix5aPopulatorService).to have_received(:new)
      expect(service).to have_received(:call)
    end
  end
end
