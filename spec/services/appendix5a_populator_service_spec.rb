RSpec.describe Appendix5aPopulatorService do
  describe '#call' do
    subject(:call) { described_class.new.call }

    before do
      allow(Appendix5a).to receive(:fetch_latest).and_return(new_guidance)
      allow(SlackNotifierService).to receive(:call).and_call_original
      allow(Appendix5aMailer).to receive_message_chain(:appendix5a_notify_message, :deliver_now)
    end

    let!(:existing_guidance) do
      create(
        :appendix_5a,
        cds_guidance: 'foo',
      )
    end

    let(:change_guidance_values) { change { existing_guidance.reload.values } }

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

      it 'sends an email notification' do
        call
        expect(Appendix5aMailer).to have_received(:appendix5a_notify_message)
          .with(0, 1, 0)
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
        expect(Appendix5aMailer).not_to have_received(:appendix5a_notify_message)
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

      it 'sends an email notification' do
        call
        expect(Appendix5aMailer).to have_received(:appendix5a_notify_message)
          .with(0, 0, 1)
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

      it 'sends an email notification' do
        call
        expect(Appendix5aMailer).to have_received(:appendix5a_notify_message)
          .with(1, 0, 0)
      end
    end
  end
end
