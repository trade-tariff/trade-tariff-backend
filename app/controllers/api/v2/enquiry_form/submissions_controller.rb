module Api
  module V2
    class EnquiryForm::SubmissionsController < ApiController
      def create
        @submission = ::EnquiryForm::Submission.create
        csv_data = ::EnquiryForm::CsvGeneratorService.new(enquiry_form_params(@submission)).generate

        ::EnquiryForm::CsvUploaderService.new(@submission, csv_data).upload
        ::EnquiryForm::SendSubmissionEmailWorker.perform_async(enquiry_form_params(@submission).to_json)

        if @submission.valid? && @submission.save
          render json: serialize(@submission), status: :created
        else
          render json: serialize_errors(@submission), status: :unprocessable_entity
        end
      end

      private

      def enquiry_form_params(submission)
        params.require(:data).require(:attributes).permit(
          :name,
          :company_name,
          :job_title,
          :email,
          :enquiry_category,
          :enquiry_description,
        ).merge(
          id: submission.id,
          reference_number: submission.reference_number,
          created_at: submission.created_at.strftime('%d/%m/%Y'),
        )
      end

      def serialize(*args)
        Api::V2::EnquiryForm::SubmissionSerializer.new(*args).serializable_hash
      end

      def serialize_errors(*args)
        Api::V2::ErrorSerializationService.new(*args).call
      end
    end
  end
end
