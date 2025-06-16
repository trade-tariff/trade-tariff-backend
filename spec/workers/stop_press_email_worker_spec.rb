RSpec.describe StopPressEmailWorker, type: :worker do
  subject(:instance) { described_class.new }

  let(:stop_press) { create(:news_item) }
  let(:user) { create(:public_user, :with_active_stop_press_subscription) }
  let(:client) { instance_double(GovukNotifier) }
  let(:email_address) { 'test@example.com' }

  before do
    allow(instance).to receive(:client).and_return(client) # rubocop:disable RSpec/SubjectStub
    allow(PublicUsers::User).to receive(:active).and_return(instance_double(Sequel::Dataset, :[] => user))
    allow(user).to receive(:email).and_return(email_address)
    allow(client).to receive(:send_email)
  end

  describe '#perform' do
    let(:expected_personalisation) do
      {
        stop_press_title: stop_press.title,
        stop_press_link: stop_press.public_url,
        subscription_reason: stop_press.subscription_reason,
        site_url: URI.join(TradeTariffBackend.frontend_host, 'subscriptions/').to_s,
        unsubscribe_url: URI.join(TradeTariffBackend.frontend_host, 'subscriptions/unsubscribe/', user.stop_press_subscription).to_s,
      }
    end

    it 'gets user email address' do
      instance.perform(stop_press.id, user.id)
      expect(user).to have_received(:email).at_least(:once)
    end

    it 'sends request to client' do
      instance.perform(stop_press.id, user.id)

      expect(client).to have_received(:send_email).with(email_address, StopPressEmailWorker::TEMPLATE_ID, expected_personalisation, StopPressEmailWorker::REPLY_TO_ID)
    end

    it 'returns if stop press is nil' do
      allow(News::Item).to receive(:find).and_return(nil)

      instance.perform(stop_press.id, user.id)

      expect(client).not_to have_received(:send_email)
    end

    context 'without valid user' do
      let(:user) { nil }

      it 'does not send email' do
        instance.perform(stop_press.id, 'invalid_user_id')
        expect(client).not_to have_received(:send_email)
      end
    end
  end
end
