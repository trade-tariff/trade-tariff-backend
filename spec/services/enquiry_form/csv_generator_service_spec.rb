RSpec.describe EnquiryForm::CsvGeneratorService do
  subject(:csv_content) { described_class.new(enquiry_data).generate }

  let(:enquiry_data) do
    {
      reference_number: 'ABC123',
      created_at: Time.zone.parse('2025-07-21 10:00'),
      name: 'Jane Doe',
      company_name: 'Jane Ltd.',
      job_title: 'Product Manager',
      email: 'jane@example.com',
      enquiry_category: 'import_duties_and_quota',
      enquiry_description: 'Need help with quotas.',
    }
  end

  it 'generates a CSV with correct headers and data' do
    csv = CSV.parse(csv_content)

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
      'Import duties and quotas',
      'Need help with quotas.',
    ])
  end

  context 'with a classification enquiry' do
    let(:enquiry_data) do
      super().merge(
        enquiry_category: 'classification',
        enquiry_description: nil,
        goods_product: 'Baked beans',
        goods_made_of: 'Beans and tomato sauce',
        goods_used_for: 'Food',
        goods_function: 'Ready to eat',
        goods_processed: 'Cooked and mixed',
        goods_packaged: 'Tinned',
        has_commodity_code: 'yes',
        commodity_code: '2005590000',
      )
    end

    it 'generates a CSV with structured classification answers' do
      csv = CSV.parse(csv_content)

      expect(csv.first).to eq([
        'Reference',
        'Submission date',
        'Full name',
        'Company name',
        'Job title',
        'Email address',
        'What do you need help with?',
        'What is the product?',
        'What is it made of?',
        'What is it used for?',
        'How does it work or function?',
        'Has it been processed, prepared or treated in any way?',
        'How is it presented or packaged?',
        'Do you already have a possible commodity code?',
        'Possible commodity code',
      ])

      expect(csv.second).to eq([
        'ABC123',
        '2025-07-21 10:00:00 UTC',
        'Jane Doe',
        'Jane Ltd.',
        'Product Manager',
        'jane@example.com',
        'Classification',
        'Baked beans',
        'Beans and tomato sauce',
        'Food',
        'Ready to eat',
        'Cooked and mixed',
        'Tinned',
        'Yes',
        '2005590000',
      ])
    end
  end

  context 'with a legacy classification enquiry' do
    let(:enquiry_data) do
      super().merge(
        enquiry_category: 'classification',
        enquiry_description: 'Legacy free text classification question.',
      )
    end

    it 'keeps the legacy free-text CSV format' do
      csv = CSV.parse(csv_content)

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
        'Classification',
        'Legacy free text classification question.',
      ])
    end
  end

  context 'with spreadsheet formula-like user input' do
    let(:enquiry_data) do
      super().merge(
        name: '=Jane Doe',
        company_name: '+Jane Ltd.',
        job_title: '-Product Manager',
        email: '@jane.example',
        enquiry_category: 'other',
        other_category: '=Other topic',
        enquiry_description: '=Need help with quotas.',
      )
    end

    it 'escapes user-controlled CSV cells without changing headers' do
      csv = CSV.parse(csv_content)

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
        "'=Jane Doe",
        "'+Jane Ltd.",
        "'-Product Manager",
        "'@jane.example",
        'Other - =Other topic',
        "'=Need help with quotas.",
      ])
    end
  end
end
