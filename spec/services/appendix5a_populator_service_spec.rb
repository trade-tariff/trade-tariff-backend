RSpec.describe Appendix5aPopulatorService do
  describe '#call' do
    subject(:call) { service.call }

    let(:service) { described_class.new }
    let!(:existing_guidance) do
      create(
        :appendix_5a,
        cds_guidance: 'foo',
      )
    end
    let(:change_guidance_values) { change { existing_guidance.reload.values } }
    let(:cupid_emails) { %w[cupid@example.com backup@example.com] }

    before do
      allow(Appendix5a).to receive(:fetch_latest).and_return(new_guidance)
      allow(SlackNotifierService).to receive(:call).and_call_original
      allow(TradeTariffBackend).to receive(:cupid_team_to_emails).and_return(cupid_emails)
      allow(Notifications::EmailWorker).to receive(:perform_async)
    end

    context 'when the latest guidance has changed' do
      let(:new_guidance) do
        {
          '1123' => {
            'guidance_cds' => 'bar',
          },
        }
      end

      it 'changes the guidance' do
        expect { call }.to change_guidance_values
      end

      it 'notifies slack' do
        call

        expect(SlackNotifierService)
          .to have_received(:call)
          .with('Appendix 5a has been updated with 0 new, 1 changed and 0 removed guidance documents')
      end

      it 'sends an email notification to each configured recipient with a String-keyed personalisation hash' do
        call

        cupid_emails.each_with_index do |email, recipient_index|
          expect(Notifications::EmailWorker).to have_received(:perform_async).with(
            email,
            described_class::TEMPLATE_ID,
            {
              'new_count' => 0,
              'changed_count' => 1,
              'removed_count' => 0,
              'support_email' => TradeTariffBackend.support_email,
            },
            'Appendix5aNotificationStatusCheckWorker',
            [recipient_index],
          )
        end
      end

      it 'enqueues via the real Sidekiq perform_async boundary without raising (Sidekiq.strict_args! guard)' do
        allow(Notifications::EmailWorker).to receive(:perform_async).and_call_original

        Sidekiq::Testing.fake! do
          Notifications::EmailWorker.jobs.clear

          expect { call }.not_to raise_error

          expect(Notifications::EmailWorker.jobs.size).to eq(cupid_emails.size)
          Notifications::EmailWorker.jobs.each do |job|
            personalisation = job['args'][2]
            expect(personalisation.keys).to all(be_a(String))
          end
        end
      end

      context 'when SlackNotifierService raises on the summary message' do
        before do
          allow(SlackNotifierService).to receive(:call).and_raise(StandardError, 'slack unavailable')
          allow(Rails.logger).to receive(:error)
        end

        it 'does not raise' do
          expect { call }.not_to raise_error
        end

        it 'still enqueues notifications for every configured recipient' do
          call

          expect(Notifications::EmailWorker).to have_received(:perform_async).exactly(cupid_emails.size).times
        end

        it 'logs the slack failure' do
          call

          expect(Rails.logger).to have_received(:error).with(
            a_string_including('appendix5a_notification_slack_failed', 'StandardError', 'slack unavailable'),
          )
        end
      end
    end

    context 'when latest guidance has not changed' do
      let(:new_guidance) do
        {
          '1123' => {
            'guidance_cds' => 'foo',
          },
        }
      end

      it 'does not change the guidance' do
        expect { call }.not_to change_guidance_values
      end

      it 'does not notify slack' do
        call

        expect(SlackNotifierService).not_to have_received(:call)
      end

      it 'does not send an email' do
        call
        expect(Notifications::EmailWorker).not_to have_received(:perform_async)
      end
    end

    context 'when latest guidance removes old guidance' do
      let(:new_guidance) { {} }

      it 'removes old guidance' do
        expect { call }.to change(Appendix5a, :count).by(-1)
      end

      it 'notifies slack' do
        call

        expect(SlackNotifierService)
          .to have_received(:call)
          .with('Appendix 5a has been updated with 0 new, 0 changed and 1 removed guidance documents')
      end

      it 'sends an email notification to each configured recipient' do
        call

        cupid_emails.each_with_index do |email, recipient_index|
          expect(Notifications::EmailWorker).to have_received(:perform_async).with(
            email, described_class::TEMPLATE_ID,
            { 'new_count' => 0, 'changed_count' => 0, 'removed_count' => 1, 'support_email' => TradeTariffBackend.support_email },
            'Appendix5aNotificationStatusCheckWorker', [recipient_index]
          )
        end
      end
    end

    context 'when latest guidance adds new guidance' do
      let(:new_guidance) do
        {
          '1123' => {
            'guidance_cds' => 'foo',
          },
          '2123' => {
            'guidance_cds' => 'foo',
          },
        }
      end

      it 'adds new guidance' do
        expect { call }.to change(Appendix5a, :count).by(1)
      end

      it 'notifies slack' do
        call

        expect(SlackNotifierService)
          .to have_received(:call)
          .with('Appendix 5a has been updated with 1 new, 0 changed and 0 removed guidance documents')
      end

      it 'sends an email notification to each configured recipient' do
        call

        cupid_emails.each_with_index do |email, recipient_index|
          expect(Notifications::EmailWorker).to have_received(:perform_async).with(
            email, described_class::TEMPLATE_ID,
            { 'new_count' => 1, 'changed_count' => 0, 'removed_count' => 0, 'support_email' => TradeTariffBackend.support_email },
            'Appendix5aNotificationStatusCheckWorker', [recipient_index]
          )
        end
      end
    end

    context 'when no recipients are configured' do
      let(:cupid_emails) { [] }
      let(:new_guidance) do
        {
          '1123' => {
            'guidance_cds' => 'bar',
          },
        }
      end

      it 'logs an error and does not raise' do
        allow(Rails.logger).to receive(:error)

        call

        expect(Rails.logger).to have_received(:error).with(
          'Appendix 5a guidance changed but CUPID_TEAM_TO_EMAILS is not configured — no notification emails were sent',
        )
      end

      it 'still changes the guidance' do
        expect { call }.to change_guidance_values
      end

      it 'still notifies slack' do
        call

        expect(SlackNotifierService)
          .to have_received(:call)
          .with('Appendix 5a has been updated with 0 new, 1 changed and 0 removed guidance documents')
      end

      it 'does not enqueue any email worker jobs' do
        call

        expect(Notifications::EmailWorker).not_to have_received(:perform_async)
      end
    end

    context 'when a recipient index no longer resolves to a configured email' do
      let(:cupid_emails) { ['cupid@example.com', ''] }
      let(:new_guidance) do
        {
          '1123' => {
            'guidance_cds' => 'bar',
          },
        }
      end

      it 'skips that recipient via Notifications::Instrumentation.send_skipped and does not enqueue an email for them' do
        allow(Notifications::Instrumentation).to receive(:send_skipped)

        call

        expect(Notifications::Instrumentation).to have_received(:send_skipped).with(
          pipeline: 'appendix5a', identifier: 1, reason: 'recipient_not_configured',
        )
        expect(Notifications::EmailWorker).to have_received(:perform_async).once
      end
    end
  end
end
