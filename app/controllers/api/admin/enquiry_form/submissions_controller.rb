module Api
  module Admin
    class EnquiryForm::SubmissionsController < AdminController
      before_action :authenticate_user!

      def index
        render json: serialize(enquiry_form_submissions)
      end

      private

      def enquiry_form_submissions
        ::EnquiryForm::Submission.all
      end

      def serialize(*args)
        Api::Admin::EnquiryForm::SubmissionSerializer.new(*args).serializable_hash
      end
    end
  end
end
