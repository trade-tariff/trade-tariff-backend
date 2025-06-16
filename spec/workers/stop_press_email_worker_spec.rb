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
        subscription_reason: 'This is a non-chapter specific update from the UK Trade Tariff Service',
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

      expect(client).to have_received(:send_email).with(email_address, StopPressEmailWorker::TEMPLATE_ID, expected_personalisation)
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
          expect(instance.subscription_reason(stop_press, user)).to eq('You have previously subscribed to receive updates about this tariff chapter - 01, 02')
        end
      end

      context 'when user has chapter subscriptions' do
        let(:user_chapters) { '01, 03' }

        it 'returns a reason with only matching chapters listed' do
          expect(instance.subscription_reason(stop_press, user)).to eq('You have previously subscribed to receive updates about this tariff chapter - 01')
        end

        context 'when whitespace does not match' do
          let(:chapters) { '01, 02, 03, 04' }
          let(:user_chapters) { '01,03,05' }

          it 'still returns a reason with only matching chapters listed' do
            expect(instance.subscription_reason(stop_press, user)).to eq('You have previously subscribed to receive updates about this tariff chapter - 01, 03')
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
