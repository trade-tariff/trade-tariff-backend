module Api
  module Admin
    class EnquiryForm::SubmissionSerializer
      include JSONAPI::Serializer

      set_type 'enquiry_form/submission'

      set_id :id

      attributes  :reference_number,
                  :email_status,
                  :csv_url,
                  :created_at,
                  :updated_at,
                  :submitted_at
    end
  end
end
