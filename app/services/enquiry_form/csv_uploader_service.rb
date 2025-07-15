class EnquiryForm::CsvUploaderService
  def initialize(form_submission, csv_data)
    @form_submission = form_submission
    @csv_data = csv_data
  end

  def upload
    file_path = filepath_for(@form_submission)
    @form_submission.update!(csv_url: file_path)
    TariffSynchronizer::FileService.write_file(file_path, csv_data)

    Rails.logger.info("Uploaded enquiry form CSV for #{form_submission.reference_number} to #{file_path}")
  end

  private

  def self.filepath_for(form_submission)
    year = form_submission.created_at.year
    month = form_submission.created_at.month

    "uk/enquiry_forms/#{year}/#{month}/#{form_submission.reference_number}.csv"
  end
end
