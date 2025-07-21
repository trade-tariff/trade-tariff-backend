require 'rails_helper'

RSpec.describe EnquiryForm::CsvGeneratorService do
  subject { described_class.new(enquiry_data).generate }

  let(:enquiry_data) do
    {
      reference_number: 'ABC123',
      created_at: Time.zone.parse('2025-07-21 10:00'),
      name: 'Jane Doe',
      company_name: 'Jane Ltd.',
      job_title: 'Product Manager',
      email: 'jane@example.com',
      enquiry_category: 'Quotas',
      enquiry_description: 'Need help with quotas.',
    }
  end

  it 'generates a CSV with correct headers and data' do
    csv = CSV.parse(subject)

    expect(csv.first).to eq([
      'Reference',
      'Submission date',
      'Full name',
      'Company name',
      'Job title',
      'Email address',
      'What do you need help with?',
      'How can we help?',
    ])

    expect(csv.second).to eq([
      'ABC123',
      '2025-07-21 10:00:00 UTC',
      'Jane Doe',
      'Jane Ltd.',
      'Product Manager',
      'jane@example.com',
      'Quotas',
      'Need help with quotas.',
    ])
  end
end
