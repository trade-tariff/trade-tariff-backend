class EnquiryForm::CsvGeneratorService
  def initialize(enquiry_form_data)
    @enquiry_form_data = enquiry_form_data.symbolize_keys!
  end

  def generate
    keys = [
          :name,
          :company_name,
          :job_title,
          :email,
          :enquiry_category,
          :enquiry_description
        ]

    CSV.generate do |csv|
      csv << keys.map { |key| key.to_s.humanize }
      csv << keys.map { |key| @enquiry_form_data[key] }
    end
  end
end
