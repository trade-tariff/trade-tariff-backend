FactoryBot.define do
  factory :enquiry_form_submission, class: 'EnquiryForm::Submission' do
    sequence(:reference_number) { 'C1KGNTQD' }
    email_status { 'Pending' }
    created_at { Time.zone.today }
    updated_at { Time.zone.today }
  end
end
