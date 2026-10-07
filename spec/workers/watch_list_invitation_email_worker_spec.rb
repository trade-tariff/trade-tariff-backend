RSpec.describe WatchListInvitationEmailWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:user) { create(:public_user) }
  let(:mock_notifier) { instance_double(GovukNotifier, send_email: nil) }

  before do
    allow(GovukNotifier).to receive(:new).and_return(mock_notifier)
    allow(IdentityApiClient).to receive(:get_email).and_return('test@example.com')
  end

  describe 'sidekiq options' do
    it 'caps retries below Sidekiq default' do
      expect(described_class.sidekiq_options['retry']).to eq(3)
    end
  end

  describe '#perform' do
    context 'when the user has an email' do
      it 'sends the invitation email' do
        worker.perform(user.id)

        expect(mock_notifier).to have_received(:send_email).with(
          'test@example.com',
          described_class::TEMPLATE_ID,
          {},
          described_class::REPLY_TO_ID,
          nil,
        )
      end
    end

    context 'when the user has no email' do
      before { allow(IdentityApiClient).to receive(:get_email).and_return(nil) }

      it 'does not send an email' do
        worker.perform(user.id)

        expect(mock_notifier).not_to have_received(:send_email)
      end
    end

    context 'when the user does not exist' do
      it 'does not send an email' do
        worker.perform(-1)

        expect(mock_notifier).not_to have_received(:send_email)
      end
    end

    context 'when Notify returns an error' do
      let(:notify_error_response) do
        instance_double(
          Net::HTTPResponse,
          code: '500',
          body: { errors: [{ error: 'Exception', message: 'Internal server error' }] }.to_json,
        )
      end

      before do
        allow(mock_notifier).to receive(:send_email)
          .and_raise(Notifications::Client::ServerError.new(notify_error_response))
      end

      it 'raises so Sidekiq retries the job' do
        expect { worker.perform(user.id) }.to raise_error(Notifications::Client::ServerError)
      end
    end
  end
end
