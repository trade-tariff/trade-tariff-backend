module Api
  module V2
    class EnquiryForm::SubmissionSerializer
      include JSONAPI::Serializer

      set_type 'enquiry_form/submission'

      set_id :reference_number
    end
  end
end
