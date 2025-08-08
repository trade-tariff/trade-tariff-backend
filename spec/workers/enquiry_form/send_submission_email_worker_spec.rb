# rubocop:disable RSpec/VerifiedDoubles
require 'rails_helper'

RSpec.describe EnquiryForm::SendSubmissionEmailWorker, type: :worker do
  describe '#perform' do
    let(:submission) { create(:enquiry_form_submission) }
    let(:form_data) do
      {
        id: submission.id,
        reference_number: submission.reference_number,
        name: 'John Doe',
        company_name: 'John Doe Ltd',
        job_title: 'Customs Officer',
        email: 'john@exmaple.com',
        enquiry_category: 'Quotas',
        enquiry_description: 'I need help with my quotas',
      }
    end

    context 'when email is successfully delivered' do
      before do
        allow(EnquiryForm::SubmissionMailer)
          .to receive(:send_email)
          .with(form_data)
          .and_return(double(deliver_now: double(delivered?: true)))
      end

      it 'updates the submission with Sent status and sets submitted_at' do
        expect {
          described_class.new.perform(form_data)
        }.to change { submission.reload.email_status }.from('Pending').to('Sent')
         .and change { submission.reload.submitted_at }.from(nil)
      end
    end

    context 'when email fails to deliver' do
      before do
        allow(EnquiryForm::SubmissionMailer)
          .to receive(:send_email)
          .with(form_data)
          .and_return(double(deliver_now: double(delivered?: false)))
      end

      it 'sets email_status to Failed and raises an error' do
        expect {
          described_class.new.perform(form_data)
        }.to raise_error('Email not delivered')

        expect(submission.reload.email_status).to eq('Failed')
      end
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
