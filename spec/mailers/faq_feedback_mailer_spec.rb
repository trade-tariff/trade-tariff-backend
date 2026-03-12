RSpec.describe FaqFeedbackMailer, type: :mailer do
  describe '#faq_feedback_message' do
    subject(:mail) { described_class.faq_feedback_message.tap(&:deliver_now) }

    before do
      create(:green_lanes_faq_feedback, category_id: 1, question_id: 1, useful: true)
      create(:green_lanes_faq_feedback, category_id: 1, question_id: 1, useful: false, session_id: SecureRandom.uuid)
    end

    it { expect(mail.subject).to eq('[HMRC Online Trade Tariff Support] UK tariff - Green Lanes FAQ Feedback Report - UK') }
    it { expect(mail.from).to eq(['no-reply@example.com']) }
    it { expect(mail.to).to eq(['user@example.com']) }
    it { expect(mail.body.encoded).to include('Green Lanes FAQ Feedback Report') }
  end
end
