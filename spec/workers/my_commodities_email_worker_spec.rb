RSpec.describe MyCommoditiesEmailWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:user) { create(:public_user, :with_my_commodities_subscription) }
  let(:date) { '08/12/2025' }
  let(:count) { 5 }
  let(:mock_notifier) { instance_double(GovukNotifier) }
  let(:notify_response) { instance_double(GovukNotifierAudit, notification_uuid: SecureRandom.uuid) }

  before do
    allow(IdentityApiClient).to receive(:get_email).and_return('test@example.com')
    allow(GovukNotifier).to receive(:new).and_return(mock_notifier)
    allow(PublicUsers::User).to receive(:active).and_return(instance_double(Sequel::Dataset, :[] => user))
    allow(mock_notifier).to receive(:send_email).and_return(notify_response)
    allow(mock_notifier).to receive(:schedule_status_check)
  end

  describe 'sidekiq options' do
    it 'caps retries below Sidekiq default' do
      expect(described_class.sidekiq_options['retry']).to eq(3)
    end
  end

  describe 'when retries are exhausted' do
    subject(:exhaust_retries) do
      described_class.sidekiq_retries_exhausted_block.call(
        { 'args' => [user.id, date, count] },
        StandardError.new('Notify is down'),
      )
    end

    before { create(:tariff_changes_job_status, :with_emails_sent, operation_date: Date.new(2025, 12, 8)) }

    it 'returns the date to the pending_emails redrive set' do
      expect { exhaust_retries }
        .to(change { TariffChangesJobStatus.pending_emails.include?(Date.new(2025, 12, 8)) }
        .from(false).to(true))
    end

    it 'clears emails_sent_at for that date' do
      expect { exhaust_retries }
        .to(change { TariffChangesJobStatus.for_date(Date.new(2025, 12, 8)).emails_sent_at }.to(nil))
    end

    it 'leaves changes_generated_at alone so the day is not regenerated' do
      expect { exhaust_retries }
        .not_to(change { TariffChangesJobStatus.for_date(Date.new(2025, 12, 8)).changes_generated_at })
    end

    context 'when the job carried no date' do
      let(:date) { nil }

      it 'does not touch any job status' do
        expect { exhaust_retries }
          .not_to(change { TariffChangesJobStatus.for_date(Date.new(2025, 12, 8)).emails_sent_at })
      end
    end
  end

  describe '#perform' do
    context 'when all parameters are valid' do
      it 'sends an email to the user' do
        worker.perform(user.id, date, count)

        expect(mock_notifier).to have_received(:send_email).with(
          'test@example.com',
          described_class::TEMPLATE_ID,
          {
            changes_count: count,
            published_date: date,
            site_url: "#{TradeTariffBackend.frontend_host}/subscriptions/mycommodities?as_of=2025-12-08&utm_source=private+beta&utm_medium=email&utm_campaign=commodity+watchlist",
            unsubscribe_url: "#{URI.join(TradeTariffBackend.frontend_host, 'subscriptions/unsubscribe/', user.my_commodities_subscription.uuid)}?utm_source=private+beta&utm_medium=email&utm_campaign=commodity+watchlist",
          },
          described_class::REPLY_TO_ID,
          nil,
        )
        expect(mock_notifier).to have_received(:schedule_status_check).with(user, notify_response)
      end
    end

    context 'when date is nil' do
      let(:date) { nil }

      it 'does not send an email' do
        worker.perform(user.id, date, count)

        expect(mock_notifier).not_to have_received(:send_email)
      end
    end

    context 'when user does not exist' do
      let(:user) { nil }

      it 'does not send an email' do
        worker.perform(999_999, date, count)

        expect(mock_notifier).not_to have_received(:send_email)
      end
    end

    context 'when user is deleted' do
      let(:user) { create(:public_user, deleted: true) }

      it 'does not send an email' do
        worker.perform(user.id, date, count)

        expect(mock_notifier).not_to have_received(:send_email)
      end
    end

    context 'when user has no email' do
      before do
        allow(IdentityApiClient).to receive(:get_email).and_return(nil)
      end

      it 'does not send an email' do
        worker.perform(user.id, date, count)

        expect(mock_notifier).not_to have_received(:send_email)
      end
    end

    context 'when user has blank email' do
      before do
        allow(IdentityApiClient).to receive(:get_email).and_return('')
      end

      it 'does not send an email' do
        worker.perform(user.id, date, count)

        expect(mock_notifier).not_to have_received(:send_email)
      end
    end

    context 'with different change counts' do
      it 'includes the correct count in the email' do
        worker.perform(user.id, date, 42)

        expect(mock_notifier).to have_received(:send_email) do |_email, _template_id, personalisation, _reply_to, _reference|
          expect(personalisation[:changes_count]).to eq(42)
        end
      end
    end

    context 'with different dates' do
      let(:date) { '15/01/2024' }

      it 'formats the date correctly' do
        worker.perform(user.id, date, count)

        expect(mock_notifier).to have_received(:send_email) do |_email, _template_id, personalisation, _reply_to, _reference|
          expect(personalisation[:published_date]).to eq(date)
        end
      end
    end

    it 'includes tracking parameters in URLs' do
      worker.perform(user.id, date, count)

      expect(mock_notifier).to have_received(:send_email) do |_email, _template_id, personalisation, _reply_to, _reference|
        expect(personalisation[:site_url]).to include('utm_source=private+beta&utm_medium=email&utm_campaign=commodity+watchlist')
        expect(personalisation[:unsubscribe_url]).to include('utm_source=private+beta&utm_medium=email&utm_campaign=commodity+watchlist')
      end
    end
  end
end
