class EnquiryForm::CsvGeneratorService
  def initialize(enquiry_form_data)
    @enquiry_form_data = enquiry_form_data.to_h.symbolize_keys
  end

  def generate
    CSV.generate do |csv|
      csv << formatter.csv_headers
      csv << formatter.csv_row
    end
  end

  private

  def formatter
    @formatter ||= EnquiryForm::SubmissionFormatter.new(@enquiry_form_data)
  end
end
