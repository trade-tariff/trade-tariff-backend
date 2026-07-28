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
      allow(Appendix5aEmailWorker).to receive(:perform_async)
      allow(service).to receive(:sleep)
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

      it 'sends an email notification to each configured recipient' do
        call

        cupid_emails.each_index do |recipient_index|
          expect(Appendix5aEmailWorker).to have_received(:perform_async).with(recipient_index, 0, 1, 0)
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

          cupid_emails.each_index do |recipient_index|
            expect(Appendix5aEmailWorker).to have_received(:perform_async).with(recipient_index, 0, 1, 0)
          end
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
        expect(Appendix5aEmailWorker).not_to have_received(:perform_async)
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

        cupid_emails.each_index do |recipient_index|
          expect(Appendix5aEmailWorker).to have_received(:perform_async).with(recipient_index, 0, 0, 1)
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

        cupid_emails.each_index do |recipient_index|
          expect(Appendix5aEmailWorker).to have_received(:perform_async).with(recipient_index, 1, 0, 0)
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

        expect(Appendix5aEmailWorker).not_to have_received(:perform_async)
      end
    end

    context 'when enqueuing fails transiently then succeeds' do
      let(:new_guidance) do
        {
          '1123' => {
            'guidance_cds' => 'bar',
          },
        }
      end

      before do
        call_count = 0
        allow(Appendix5aEmailWorker).to receive(:perform_async) do
          call_count += 1
          raise StandardError, 'connection refused' if call_count == 1
        end
      end

      it 'retries and eventually enqueues every recipient' do
        call

        expect(Appendix5aEmailWorker).to have_received(:perform_async).with(0, 0, 1, 0).exactly(2).times
        expect(Appendix5aEmailWorker).to have_received(:perform_async).with(1, 0, 1, 0).exactly(1).time
      end

      it 'sleeps between retry passes' do
        call

        expect(service).to have_received(:sleep).with(30.seconds)
      end

      it 'does not send a failure alert once retries succeed' do
        call

        expect(SlackNotifierService).not_to have_received(:call).with(a_string_including('failed to enqueue'))
      end
    end

    context 'when enqueuing repeatedly fails for one recipient' do
      let(:new_guidance) do
        {
          '1123' => {
            'guidance_cds' => 'bar',
          },
        }
      end

      before do
        allow(Appendix5aEmailWorker).to receive(:perform_async) do |recipient_index, *|
          raise StandardError, 'connection refused' if recipient_index == 1
        end
        allow(Rails.logger).to receive(:error)
      end

      it 'gives up after 3 attempts and logs an error for the failing recipient' do
        call

        expect(Appendix5aEmailWorker).to have_received(:perform_async).with(1, 0, 1, 0).exactly(3).times
        expect(Rails.logger).to have_received(:error).with(
          a_string_including('appendix5a_notification_enqueue failed', 'recipient_index: 1', 'attempt: 3'),
        )
      end

      it 'alerts slack naming the failing recipient index' do
        call

        expect(SlackNotifierService).to have_received(:call).with(a_string_including('recipient index 1'))
      end

      it 'still enqueues the recipient that succeeded' do
        call

        expect(Appendix5aEmailWorker).to have_received(:perform_async).with(0, 0, 1, 0).once
      end
    end

    context 'when enqueuing fails for every recipient on every attempt' do
      let(:new_guidance) do
        {
          '1123' => {
            'guidance_cds' => 'bar',
          },
        }
      end

      before do
        allow(Appendix5aEmailWorker).to receive(:perform_async).and_raise(StandardError, 'connection refused')
        allow(Rails.logger).to receive(:error)
      end

      it 'retries every recipient the maximum number of times' do
        call

        cupid_emails.each_index do |recipient_index|
          expect(Appendix5aEmailWorker).to have_received(:perform_async).with(recipient_index, 0, 1, 0).exactly(3).times
        end
      end

      it 'sleeps between passes but not after the final attempt' do
        call

        expect(service).to have_received(:sleep).with(30.seconds).exactly(2).times
      end

      it 'alerts slack naming every failing recipient index' do
        call

        expect(SlackNotifierService).to have_received(:call).with(a_string_including('recipient index 0, 1'))
      end
    end
  end
end
