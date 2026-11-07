RSpec.describe ImageDescriptionWorker do
  let(:id) { SecureRandom.uuid }
  let(:job) { instance_double(ImageDescription, claim: { 'request_id' => 'journey' }, complete: nil, fail: nil, cleanup: nil) }
  let(:result) { { 'description' => 'Apple', 'uncertainties' => [] } }

  before do
    allow(ImageDescription).to receive(:new).with(id).and_return(job)
    allow(ImageDescriptions::Normalise).to receive(:call).with(job).and_return('/normalised.jpg')
    allow(ImageDescriptions::Describe).to receive(:call).with('/normalised.jpg', request_id: 'journey').and_return(result)
  end

  it 'completes and deletes image files' do
    described_class.new.perform(id)

    expect(job).to have_received(:complete).with(result)
    expect(job).to have_received(:cleanup)
  end

  it 'skips duplicate deliveries' do
    allow(job).to receive(:claim).and_return(nil)
    described_class.new.perform(id)

    expect(ImageDescriptions::Normalise).not_to have_received(:call)
    expect(job).not_to have_received(:cleanup)
  end

  it 'handles an invalid image safely' do
    allow(ImageDescriptions::Normalise).to receive(:call).and_raise(ImageDescriptions::Normalise::InvalidImage, 'Choose a still image.')
    described_class.new.perform(id)

    expect(job).to have_received(:fail).with('Choose a still image.')
    expect(job).to have_received(:cleanup)
    expect(ImageDescriptions::Describe).not_to have_received(:call)
  end

  it 'does not expose provider errors' do
    allow(ImageDescriptions::Describe).to receive(:call).and_raise(StandardError, 'private provider response')
    described_class.new.perform(id)

    expect(job).to have_received(:fail).with('Image description is temporarily unavailable. Try again or type a description.')
    expect(job).to have_received(:cleanup)
  end

  it 'processes jobs in production without a backend feature flag' do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new('production'))
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('IMAGE_DESCRIPTIONS_ENABLED').and_return(nil)
    described_class.new.perform(id)

    expect(job).to have_received(:complete).with(result)
    expect(job).to have_received(:cleanup)
  end
end
