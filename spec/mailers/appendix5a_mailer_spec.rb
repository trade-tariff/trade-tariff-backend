RSpec.describe Appendix5aMailer, type: :mailer do
  describe '#appendix5a_notify_message' do
    subject(:mail) { described_class.appendix5a_notify_message(2, 3, 1).tap(&:deliver_now) }

    it { expect(mail.subject).to eq('[OTT has made updates from appendix 5a: 2 new, 3 changed, 1 removed CDS guidance documents]') }
    it { expect(mail.from).to eq(['no-reply@example.com']) }
    it { expect(mail.to).to eq(['cupid@example.com']) }
    it { expect(mail.body.encoded).to include('Dear CUPID team') }
  end
end
