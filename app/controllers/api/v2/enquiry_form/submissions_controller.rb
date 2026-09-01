module Api
  module V2
    class EnquiryForm::SubmissionsController < ApiController
      CACHE_DURATION = 1.hour
      SubmissionResult = Data.define(:reference_number)

      def create
        submission = ::EnquiryForm::Submission.from(enquiry_form_data)

        store_enquiry_form_data(submission)
        enqueue_submission_emails(submission)

        begin
          render json: serialize(SubmissionResult.new(reference_number:)), status: :created
        rescue ActionController::ParameterMissing => e
          render json: { errors: [e.message] }, status: :unprocessable_content
        end
      end

    private

      def store_enquiry_form_data(submission)
        Sidekiq.redis do |conn|
          conn.set(
            ::EnquiryForm::SendSubmissionEmailWorker.cache_key(reference_number),
            submission.to_h.to_json,
            ex: CACHE_DURATION.to_i,
          )
        end
      end

      def enqueue_submission_emails(submission)
        jobs = submission.audiences.map { |audience| [reference_number, audience] }

        ::EnquiryForm::SendSubmissionEmailWorker.perform_bulk(jobs)
      end

      def enquiry_form_params
        params.require(:data).require(:attributes).permit(
          :name,
          :company_name,
          :job_title,
          :email,
          :enquiry_category,
          :other_category,
          :enquiry_description,
          :test_condition,
          :search_request_id,
          :goods_product,
          :goods_made_of,
          :goods_used_for,
          :goods_function,
          :goods_processed,
          :goods_packaged,
          :has_commodity_code,
          :commodity_code,
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
