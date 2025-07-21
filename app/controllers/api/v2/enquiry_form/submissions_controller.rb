class Api::V2::EnquiryForm::SubmissionsController < ApiController
  def create
    @submission = EnquiryForm::Submission.new(submission_params)
    csv_data = EnquiryForm::CsvGeneratorService.new(submission_params).generate

    EnquiryForm::CsvUploaderService.new(@submission, csv_data).upload
    # EnquiryForm::SubmissionMailer.send_email(@submission).deliver_later

    if @submission.valid? && @submission.save
      render json: @submission.reference_number, status: :created
    else
      render json: @submission.errors, status: :unprocessable_entity
    end
  end

  private

  def submission_params
    params.require(:submission).permit(:data)
  end
end
