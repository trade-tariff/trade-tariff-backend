RSpec.describe SpellingFileUploaderWorker, type: :worker do
  before do
    allow(SpellingCorrector::FileUpdaterService).to receive(:new).and_return(file_updater_service)

    silence { described_class.new.perform }
  end

  let(:file_updater_service) { instance_double('SpellingCorrector::FileUpdaterService', call: 'foo') }

  it { expect(file_updater_service).to have_received(:call) }
end
