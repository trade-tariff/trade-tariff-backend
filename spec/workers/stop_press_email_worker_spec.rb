RSpec.describe StopPressEmailWorker, type: :worker do
  subject(:instance) { described_class.new }

  let(:stop_press) { create(:news_item) }
  let(:user) { create(:public_user, :with_active_stop_press_subscription) }
  let(:client) { instance_double(GovukNotifier) }
  let(:email_address) { 'test@example.com' }

  before do
    allow(instance).to receive(:client).and_return(client) # rubocop:disable RSpec/SubjectStub
    allow(user).to receive(:email).and_return(email_address)
    allow(PublicUsers::User).to receive(:find).and_return(user)
    allow(client).to receive(:send_email)
  end

  describe '#perform' do
    let(:expected_personalisation) do
      {
        stop_press_title: stop_press.title,
        stop_press_link: stop_press.public_url,
        subscription_reason: stop_press.subscription_reason,
        site_url: String,
        unsubscribe_url: '',
      }
    end

    it 'gets user email address' do
      instance.perform(stop_press.id, user.id)
      expect(user).to have_received(:email).at_least(:once)
    end

    it 'sends request to client' do
      instance.perform(stop_press.id, user.id)

      expect(client).to have_received(:send_email).with(email_address, StopPressEmailWorker::TEMPLATE_ID, expected_personalisation)
    end
  end
end
