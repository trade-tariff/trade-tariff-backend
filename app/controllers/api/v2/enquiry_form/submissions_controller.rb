module Api
  module V2
    class EnquiryForm::SubmissionsController < ApiController
      CACHE_DURATION = 1.hour

      def create
        store_enquiry_form_data

        ::EnquiryForm::SendSubmissionEmailWorker.perform_async(reference_number)

        begin
          render json: serialize(OpenStruct.new(reference_number: reference_number)), status: :created
        rescue ActionController::ParameterMissing => e
          render json: { errors: [e.message] }, status: :unprocessable_content
        end
      end

      private

      def store_enquiry_form_data
        Rails.cache.write(
          EnquiryForm::SendSubmissionEmailWorker.cache_key(reference_number),
          enquiry_form_data.to_json,
          expires_in: CACHE_DURATION,
        )
      end

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
        enquiry_form_params.merge(reference_number: reference_number, created_at: created_at)
      end

      def serialize(*args)
        Api::V2::EnquiryForm::SubmissionSerializer.new(*args).serializable_hash
      end

      def serialize_errors(*args)
        Api::V2::ErrorSerializationService.new(*args).call
      end

      def reference_number
        @reference_number ||= CreateReferenceNumberService.new.call
      end

      def created_at
        @created_at ||= Time.zone.now.strftime('%Y-%m-%d %H:%M')
      end
    end
  end
end
