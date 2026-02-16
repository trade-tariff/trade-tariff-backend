RSpec.describe StopPressEmailWorker, type: :worker do
  subject(:instance) { described_class.new }

  let(:stop_press) { create(:news_item) }
  let(:user) { create(:public_user, :with_active_stop_press_subscription) }
  let(:client) { instance_double(GovukNotifier) }
  let(:email_address) { 'test@example.com' }
  let(:notification_id) { SecureRandom.uuid }
  let(:notify_response) { instance_double(GovukNotifierAudit, notification_uuid: notification_id) }

  before do
    allow(IdentityApiClient).to receive(:get_email).and_return(email_address)
    allow(GovukNotifier).to receive(:new).and_return(client)
    allow(PublicUsers::User).to receive(:active).and_return(instance_double(Sequel::Dataset, :[] => user))
    allow(client).to receive(:send_email).and_return(notify_response)
    allow(client).to receive(:schedule_status_check)
  end

  describe '#perform' do
    let(:expected_personalisation) do
      {
        stop_press_title: stop_press.title,
        stop_press_link: "#{stop_press.public_url}?utm_source=private+beta&utm_medium=email&utm_campaign=stop+press+notification",
        subscription_reason: 'This is a non-chapter specific update from the UK Trade Tariff Service',
        site_url: "#{URI.join(TradeTariffBackend.frontend_host, 'subscriptions/')}?utm_source=private+beta&utm_medium=email&utm_campaign=stop+press+notification",
        unsubscribe_url: "#{URI.join(TradeTariffBackend.frontend_host, 'subscriptions/unsubscribe/', user.stop_press_subscription)}?utm_source=private+beta&utm_medium=email&utm_campaign=stop+press+notification",
      }
    end

    it 'gets user email address' do
      allow(user).to receive(:email).and_return(email_address)
      instance.perform(stop_press.id, user.id)
      expect(user).to have_received(:email).at_least(:once)
    end

    it 'sends request to client' do
      instance.perform(stop_press.id, user.id)

      expect(client).to have_received(:send_email).with(email_address, StopPressEmailWorker::TEMPLATE_ID, expected_personalisation, StopPressEmailWorker::REPLY_TO_ID, nil)
      expect(client).to have_received(:schedule_status_check).with(user, notify_response)
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

    it 'includes tracking parameters in URLs' do
      instance.perform(stop_press.id, user.id)

      expect(client).to have_received(:send_email) do |_email, _template, personalisation, _reply_to, _reference|
        expect(personalisation[:site_url]).to include('utm_source=private+beta&utm_medium=email&utm_campaign=stop+press+notification')
        expect(personalisation[:unsubscribe_url]).to include('utm_source=private+beta&utm_medium=email&utm_campaign=stop+press+notification')
      end
    end
  end

  describe '#subscription_reason' do
    before do
      allow(stop_press).to receive(:chapters).and_return(chapters)
      allow(user).to receive(:chapter_ids).and_return(user_chapters)
    end

    context 'when stop press has chapters' do
      let(:chapters) { '01, 02' }

      context 'when user has no chapter subscriptions' do
        let(:user_chapters) { '' }

        it 'returns a reason with all chapters listed' do
          expect(instance.subscription_reason(stop_press, user)).to eq('You have previously subscribed to receive updates about tariff chapters - 01, 02')
        end
      end

      context 'when stop press chapters have irregular whitespace' do
        let(:chapters) { '01,02, 03,04' }
        let(:user_chapters) { '' }

        it 'returns a reason with all chapters listed regularly' do
          expect(instance.subscription_reason(stop_press, user)).to eq('You have previously subscribed to receive updates about tariff chapters - 01, 02, 03, 04')
        end
      end

      context 'when stop press chapters have duplicates' do
        let(:chapters) { '01,02,03,01,02' }
        let(:user_chapters) { '' }

        it 'returns a reason with all chapters listed regularly' do
          expect(instance.subscription_reason(stop_press, user)).to eq('You have previously subscribed to receive updates about tariff chapters - 01, 02, 03')
        end
      end

      context 'when user has chapter subscriptions' do
        let(:user_chapters) { '01, 03' }

        it 'returns a reason with only matching chapters listed' do
          expect(instance.subscription_reason(stop_press, user)).to eq('You have previously subscribed to receive updates about tariff chapter - 01')
        end

        context 'when whitespace does not match' do
          let(:chapters) { '01, 02, 03, 04' }
          let(:user_chapters) { '01,03,05' }

          it 'still returns a reason with only matching chapters listed' do
            expect(instance.subscription_reason(stop_press, user)).to eq('You have previously subscribed to receive updates about tariff chapters - 01, 03')
          end
        end
      end
    end

    context 'when stop press has no chapters' do
      let(:chapters) { nil }

      context 'when user has no chapter subscriptions' do
        let(:user_chapters) { '' }

        it 'returns the non-chapter reason' do
          expect(instance.subscription_reason(stop_press, user)).to eq('This is a non-chapter specific update from the UK Trade Tariff Service')
        end
      end

      context 'when user has chapter subscriptions' do
        let(:user_chapters) { '01, 03' }

        it 'returns the non-chapter reason' do
          expect(instance.subscription_reason(stop_press, user)).to eq('This is a non-chapter specific update from the UK Trade Tariff Service')
        end
      end
    end
  end
end
