RSpec.describe SearchReferenceChangesReportWorker, type: :worker do
  let(:result) { instance_double(Reporting::SearchReferenceChanges::Result) }
  let(:mail) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

  before do
    allow(Reporting::SearchReferenceChanges).to receive(:generate).and_return(result)
    allow(ReportsMailer).to receive(:search_reference_changes).and_return(mail)
  end

  context 'when delivering the email' do
    before { described_class.new.perform }

    it { expect(Reporting::SearchReferenceChanges).to have_received(:generate) }
    it { expect(ReportsMailer).to have_received(:search_reference_changes).with(result) }
    it { expect(mail).to have_received(:deliver_now) }
  end

  context 'when not delivering the email' do
    before { described_class.new.perform(false) }

    it { expect(Reporting::SearchReferenceChanges).to have_received(:generate) }
    it { expect(ReportsMailer).not_to have_received(:search_reference_changes) }
  end
end
