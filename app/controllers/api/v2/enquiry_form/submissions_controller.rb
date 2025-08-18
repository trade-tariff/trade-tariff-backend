module Api
  module V2
    class EnquiryForm::SubmissionsController < ApiController
      include ::EnquiryForm::SubmissionHelper
      before_action :set_reference_number, only: [:create]

      def create
        @csv_data = ::EnquiryForm::CsvGeneratorService.new(enquiry_form_data).generate
        ::EnquiryForm::SendSubmissionEmailWorker.perform_async(enquiry_form_data.to_json, @csv_data)

        begin
          render json: serialize(OpenStruct.new(reference_number: @set_reference_number)), status: :created
        rescue ActionController::ParameterMissing => e
          render json: { errors: [e.message] }, status: :unprocessable_content
        end
      end

      private

      def enquiry_form_params
        params.require(:data).require(:attributes).permit(
          :name,
          :company_name,
          :job_title,
          :email,
          :enquiry_category,
          :enquiry_description,
        )
      end

      def enquiry_form_data
        enquiry_form_params.merge(
          reference_number: @set_reference_number,
          created_at: Time.zone.now.strftime('%Y-%m-%d %H:%M'),
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
