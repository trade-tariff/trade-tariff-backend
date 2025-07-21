RSpec.describe EnquiryForm::Submission, type: :model do
  subject(:submission) { described_class.new }

  describe '#before_validation' do
    it 'generates a unique reference_number' do
      expect(submission.reference_number).to be_nil
      submission.valid?
      expect(submission.reference_number).to match(/\A[A-Z0-9]{8}\z/)
    end

    it 'defaults email_status to Pending if not set' do
      submission.valid?
      expect(submission.email_status).to eq('Pending')
    end
  end

  describe 'validations' do
    it 'is invalid with an unsupported email_status' do
      submission.email_status = 'Unknown'
      submission.validate
      expect(submission.errors[:email_status]).to include(/is not in range/)
    end
  end

  describe '#before_save' do
    it 'sets submitted_at only when email_status changes to Sent' do
      submission.email_status = 'Sent'
      submission.valid?
      expect(submission.submitted_at).to be_nil

      submission.save
      expect(submission.submitted_at).not_to be_nil
    end
  end
end
