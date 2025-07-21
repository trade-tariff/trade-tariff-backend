class EnquiryForm::CsvUploaderService
  def initialize(submission, csv_data)
    @submission = submission
    @csv_data = csv_data
  end

  def upload
    file_path = filepath_for(@submission)
    @submission.update(csv_url: file_path)
    TariffSynchronizer::FileService.write_file(file_path, @csv_data)

    Rails.logger.info("Uploaded enquiry form CSV for #{@submission.reference_number} to #{file_path}")
  end

  def filepath_for(submission)
    year = submission.created_at.year
    month = submission.created_at.month

    "uk/enquiry_forms/#{year}/#{month}/#{submission.reference_number}.csv"
  end
end
