module Api
  module Internal
    class EnquiryForm::SubmissionSerializer
      include JSONAPI::Serializer

      set_type 'enquiry_form/submission'

      set_id :reference_number
    end
  end
end
