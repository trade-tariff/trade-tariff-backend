module Api
  module V2
    class EnquiryForm::RevisedSubmissionsController < EnquiryForm::SubmissionsController
      private

      def enquiry_form_params
        params.require(:data).require(:attributes).permit(
          :name,
          :company_name,
          :job_title,
          :email,
          :enquiry_category,
          :other_category,
          :enquiry_description,
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
    end
  end
end
