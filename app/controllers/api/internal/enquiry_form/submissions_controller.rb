module Api
  module Internal
    class EnquiryForm::SubmissionsController < InternalController
      CACHE_DURATION = 1.hour
      SubmissionResult = Data.define(:reference_number)

      def create
        submission = ::EnquiryForm::Submission.from(enquiry_form_data)

        store_enquiry_form_data(submission)
        enqueue_submission_emails(submission)

        render json: serialize(SubmissionResult.new(reference_number:)), status: :created
      end

    private

      def store_enquiry_form_data(submission)
        Sidekiq.redis do |conn|
          conn.set(
            ::EnquiryForm::SendSubmissionEmailWorker.cache_key(reference_number),
            submission.cache_payload.to_json,
            ex: CACHE_DURATION.to_i,
          )
        end
      end

      def enqueue_submission_emails(submission)
        ::EnquiryForm::SendSubmissionEmailWorker.perform_async(reference_number)

        return unless submission.audiences.include?(::EnquiryForm::Submission::TRADE_TARIFF_AUDIENCE)

        ::EnquiryForm::SendTradeTariffSubmissionEmailWorker.perform_in(5.minutes, reference_number)
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
          :search_request_id,
          :goods_product,
          :goods_made_of,
          :goods_used_for,
          :goods_function,
          :goods_processed,
          :goods_packaged,
          :has_commodity_code,
          :commodity_code,
          feature_flags: [],
        )
      end

      def enquiry_form_data
        enquiry_form_params.merge(reference_number: reference_number, created_at: created_at)
      end

      def serialize(*args)
        Api::Internal::EnquiryForm::SubmissionSerializer.new(*args).serializable_hash
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
