RSpec.describe FaqFeedbackReportWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:message) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

  before do
    allow(FaqFeedbackMailer).to receive(:faq_feedback_message).and_return(message)
  end

  describe '#perform' do
    context 'when on the xi service' do
      before { allow(TradeTariffBackend).to receive(:uk?).and_return(false) }

      context 'with the default deliver email argument' do
        it 'sends the faq feedback report' do
          worker.perform

          expect(message).to have_received(:deliver_now)
        end
      end

      context 'when deliver email is false' do
        it 'does not send the faq feedback report' do
          worker.perform(false)

          expect(FaqFeedbackMailer).not_to have_received(:faq_feedback_message)
        end
      end
    end

    context 'when on the uk service' do
      before { allow(TradeTariffBackend).to receive(:uk?).and_return(true) }

      it 'does not send the faq feedback report' do
        worker.perform

        expect(FaqFeedbackMailer).not_to have_received(:faq_feedback_message)
      end
    end
  end
end
