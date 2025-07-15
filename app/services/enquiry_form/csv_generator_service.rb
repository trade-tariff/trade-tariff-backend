class EnquiryForm::CsvGeneratorService
  def initialize(enquiry_form_data)
    @enquiry_form_data = enquiry_form_data.symbolize_keys!
  end

  def generate
    headers = [
      'Reference',
     	'Submitted at',
     	'Full name',
     	'Company name',
      'Job title',
     	'Email address',
     	'What do you need help with?',
      'How can we help?'
    ]

    keys = [
          :reference_number,
          :created_at,
          :name,
          :company_name,
          :job_title,
          :email,
          :enquiry_category,
          :enquiry_description
        ]

    CSV.generate do |csv|
      csv << headers
      csv << keys.map { |key| @enquiry_form_data[key] }
    end
  end
end
